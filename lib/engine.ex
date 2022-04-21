defmodule Workflow.Engine do
    use Oban.Worker

    alias Workflow.Repo
    alias Workflow.{Flow, Reporter, Process, Task, Field}

    def context_changeset(context, params, fields, validations) do
        types = Field.ecto_types(fields)

        changeset = {context, types}
        |> Ecto.Changeset.cast(params, Field.ecto_fields(fields))
        |> Ecto.Changeset.validate_required(Field.ecto_required_fields(fields))
        
        for validation <- validations, reduce: changeset do
            changeset -> validation.(changeset, params)
        end

        changeset
    end

    def create_workflow(flow_type, process_params, context_params, opts \\ []) do
        flow = Flow.get_flow(flow_type)
        node = Flow.get_flow_node(flow, "start")

        process_params = process_params |> Map.put(:created_by_id, Keyword.get(opts, :created_by, nil))
        
        Repo.transaction fn ->
            changeset = context_changeset(Field.data(node.fields), context_params, node.fields, node.validations)

            with {:ok, context} <- Ecto.Changeset.apply_action(changeset, :insert),
                 {:ok, process} <- Repo.insert(
                    Process.creation_changeset(
                        %Process{}, 
                        process_params |> Map.put(:context, context)
                    )
                 ),
                 {:ok, task}    <- create_task(%{process_id: process.id, flow_node_name: "start"}, opts)
            do
                {process, task}
            end
        end
    end

    def process_user_action(task, context_params, opts \\ []) do
        process = Repo.get(Process, task.process_id)
        node = Task.get_flow_node(task)

        Repo.transaction fn ->
            changeset = context_changeset(process.context, context_params, node.fields, node.validations)

            with {:ok, context} <- Ecto.Changeset.apply_action(changeset, :update),
                 {:ok, process} <- Process.update_changeset(process, %{context: context}) |> Repo.update(),
                 {:ok, task}    <- Task.update_changeset(task, %{status: "done"}) |> Repo.update()
            do
                if Keyword.get(opts, :schedule, true) do
                    with {:ok, _} <- schedule_task(task) do
                        task
                    end
                else
                    task
                end
            else
                {:error, error} -> error
            end
        end
    end

    def schedule_task(%{id: id} = _task) do
        %{id: id}
        |> Workflow.Engine.new()
        |> Oban.insert()
    end

    defp create_task(task_params, opts \\ []) do
        task_params = task_params
        |> Map.put(:status, "created")
        |> Map.put(:started_at, NaiveDateTime.utc_now())

        Repo.transaction fn ->
            with {:ok, task} <- Task.creation_changeset(%Task{}, task_params) |> Repo.insert() do
                if Keyword.get(opts, :schedule, true) do
                    case schedule_task(task) do
                        {:ok, _} -> task
                        other -> other
                    end
                else
                    task
                end
            else
                {:error, error} -> error
            end
        end
    end

    defp terminate_task(task, status, params \\ %{}) do
        params = Map.merge(params, %{status: status, finished_at: NaiveDateTime.utc_now()})
        with {:ok, task} <- Task.update_changeset(task, params) |> Repo.update()
        do
            Reporter.notify_task_termination(task)
            {:ok, task}
        end
    end

    defp close_task(task) do
        terminate_task(task, "finished")
    end

    defp failed_task(task, reason \\ "") do
        terminate_task(task, "failed", %{status_complement: reason})
    end

    defp terminate_process(process, status \\ "finished", params \\ %{}) do
        params = Map.merge(params, %{status: status, finished_at: NaiveDateTime.utc_now()})
        with {:ok, process} <- Repo.update Process.update_changeset(process, params)
        do
            Reporter.notify_process_termination(process)
            {:ok, process}
        end
    end

    def close_process(process) do
        terminate_process(process, "finished")
    end

    defp failed_process(process, reason \\ "") do
        terminate_process(process, "failed", %{status_complement: reason})   
    end

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"id" => task_id}}) do
        task = Repo.get(Task, task_id)
        step(task)        
    end
    
    def step(task, opts \\ []) do
        process = Repo.get(Process, task.process_id)
        Repo.transaction fn -> pstep(task, process, opts) end
    end

    defp pstep(%{flow_node_name: flow_node_name} = task, process, opts \\ []) do
        flow        = Workflow.Flow.get_flow(process.flow_type)
        flow_node   = Workflow.Flow.get_flow_node(flow, flow_node_name)
        
        case flow_node do
            nil -> 
                {:ok, task}     = failed_task(task, "unknown flow node #{flow_node_name} for #{process.flow_type}")
                {:ok, process}  = failed_process(process, "unknown flow node #{flow_node_name} for #{process.flow_type}")
                {task, [], process}
            flow_node -> 
                unless task.status in ["finished", "failed"] do
                    case flow_node do
                        %Workflow.Flow.Nodes.Start{next: next_node} ->  
                            task_params = %{process_id: process.id, flow_node_name: next_node, parent_task_id: task.id}
                            with {:ok, next_task} <- create_task(task_params, opts),
                                {:ok, task}       <- close_task(task) 
                            do
                                {task, [next_task], process}
                            end

                        %Workflow.Flow.Nodes.End{} ->
                            with {:ok, task}   <- close_task(task),
                                {:ok, process} <- close_process(process) 
                            do
                                {task, [], process}
                            end
                        
                        %Workflow.Flow.Nodes.Subprocess{init: init_fn, result: result_fn, next: next_node} ->
                            case task.status do 
                                "created" -> 
                                    with {:ok, subprocess} <- init_fn.(process.context),
                                         {:ok, task} <- Repo.update Task.update_changeset(task, %{subprocess_id: subprocess.id, status: "idling"}) do
                                        {task, [subprocess], process}
                                    end
                                "idling" -> 
                                    {task, [], process}
                                "subprocess_terminated" ->
                                    task_params = %{process_id: process.id, flow_node_name: next_node, parent_task_id: task.id}
                                    with {:ok, subprocess} <- Process.get(task.subprocess_id), 
                                            {:ok, context_params} <- result_fn.(subprocess, process.context),
                                            {:ok, next_task}      <- create_task(task_params, opts),
                                            {:ok, task}           <- close_task(task)
                                    do
                                        {task, [next_task], process}
                                    end
                            end

                        %Workflow.Flow.Nodes.Condition{predicate: predicate?, if_node: if_node, else_node: else_node} ->
                            next_node = if(predicate?.(process.context), do: if_node, else: else_node)
                            task_params = %{process_id: process.id, flow_node_name: next_node, parent_task_id: task.id}
                            with {:ok, next_task} <- create_task(task_params, opts),
                                {:ok, task} <- close_task(task)
                            do
                                {task, [next_task], process}
                            end

                        %Workflow.Flow.Nodes.UserAction{assign_user: assign_user_fn, next: next_node} ->
                            case task.status do
                                "created" ->
                                    with {:ok, task} <- Task.update_changeset(task, %{
                                        assigned_to_id: assign_user_fn.(process.context),
                                        status: "idling"
                                    }) |> Repo.update() do
                                        {task, [], process}
                                    end
                                "idling" ->
                                    {task, [], process}
                                "done" ->
                                    task_params = %{process_id: process.id, flow_node_name: next_node, parent_task_id: task.id}
                                    with {:ok, next_task} <- create_task(task_params, opts),
                                        {:ok, task} <- close_task(task)
                                    do
                                        {task, [next_task], process}
                                    end
                                _ -> 
                                    {:ok, task} = failed_task(task, "unknown state #{task.status} for user action")
                                    {task, [], process}
                            end

                        %Workflow.Flow.Nodes.Job{work: work, next: next_node} ->
                            with {:ok, context} <- work.(process.context),
                                 {:ok, process} <- Process.update_changeset(process, %{context: context}) |> Repo.update(),
                                 {:ok, next_task} <- create_task(%{process_id: process.id, flow_node_name: next_node}, opts),
                                 {:ok, task} <- close_task(task) 
                            do
                                {task, [next_task], process}
                            else
                                {:error, error} -> 
                                    {task |> failed_task(error), [], process |> failed_process(error)}
                            end
                        _ -> {task, [], process}
                    end
                else
                    {task, [], process}
                end
        end
    end
end
