defmodule Workflow.Reporter do
    def notify_process_termination(_process) do
        
    end

    def notify_task_termination(_task) do
    end
end

defmodule Workflow.Engine do
    use Oban.Worker

    @repo Workflow.Repo

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

        @repo.transaction fn ->
            changeset = context_changeset(Field.data(node.fields), context_params, node.fields, node.validations)

            with {:ok, context} <- Ecto.Changeset.apply_action(changeset, :insert),
                 {:ok, process} <- @repo.insert(Process.creation_changeset %Process{}, process_params |> Map.put(:context, context)),
                 {:ok, task}    <- create_task(%{process_id: process.id, flow_node_name: "start"}, opts)
            do
                {process, task}
            end
        end
    end

    def process_user_action(task, context_params, opts \\ []) do
        process = @repo.get(Process, task.process_id)
        node = Task.get_flow_node(task)

        @repo.transaction fn ->
            changeset = context_changeset(process.context, context_params, node.fields, node.validations)

            with {:ok, context} <- Ecto.Changeset.apply_action(changeset, :update),
                 {:ok, process} <- Process.update_changeset(process, %{context: context}) |> @repo.update(),
                 {:ok, task} <- Task.update_changeset(task, %{status: "done"}) |> @repo.update()
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

    defp schedule_task(%{id: id} = _task) do
        %{id: id}
        |> Workflow.Engine.new()
        |> Oban.insert()
    end

    defp create_task(task_params, opts \\ []) do
        task_params = task_params
        |> Map.put(:status, "created")
        |> Map.put(:started_at, NaiveDateTime.utc_now())

        @repo.transaction fn ->
            with {:ok, task} <- Task.creation_changeset(%Task{}, task_params) |> @repo.insert() do
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
        with {:ok, task} <- Task.update_changeset(task, params) |> @repo.update()
        do
            Reporter.notify_task_termination(task)
            {:ok, task}
        end
    end

    defp close_task(task) do
        terminate_task(task, "finished")
    end

    defp failed_task(task) do
        terminate_task(task, "failed")
    end

    defp terminate_process(process, status \\ "finished") do
        with {:ok, process} <- Process.update_changeset(process, %{status: status, finished_at: NaiveDateTime.utc_now()})
        |> @repo.update() do
            Reporter.notify_process_termination(process)
            {:ok, process}
        end
    end

    def close_process(process) do
        terminate_process(process, "finished")
    end

    defp failed_process(process) do
        terminate_process(process, "failed")   
    end

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"id" => task_id}}) do
        task = @repo.get(Task, task_id)
        step(task)        
    end
    
    def step(task, opts \\ []) do
        process = @repo.get(Process, task.process_id)
        @repo.transaction fn -> pstep(task, process, opts) end
    end

    defp pstep(%{flow_node_name: flow_node_name} = task, process, opts \\ []) do
        flow        = Workflow.Flow.get_flow(process.flow_type)
        flow_node   = Workflow.Flow.get_flow_node(flow, flow_node_name)
        
        case flow_node do
            nil -> 
                {:ok, task}     = failed_task(task)
                {:ok, process}  = failed_process(process)
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
                        
                        %Workflow.Flow.Nodes.Subprocess{init: _init_fn, result: _result_fn, next: next_node} ->
                            case task.status do 
                                "created" -> {task, [], process}
                                "idling" -> {task, [], process}
                                "done" ->
                                    task_params = %{process_id: process.id, flow_node_name: next_node, parent_task_id: task.id}
                                    with {:ok, next_task} <- create_task(task_params, opts),
                                        {:ok, task} <- close_task(task)
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
                                    }) |> @repo.update() do
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
                                    {:ok, task} = failed_task(task)
                                    {task, [], process}
                            end

                        %Workflow.Flow.Nodes.Job{work: work, next: next_node} ->
                            with {:ok, context} <- work.(process.context),
                                 {:ok, process} <- Process.update_changeset(process, %{context: context}) |> @repo.update(),
                                 {:ok, next_task} <- create_task(%{process_id: process.id, flow_node_name: next_node}, opts),
                                 {:ok, task} <- close_task(task) 
                            do
                                {task, [next_task], process}
                            else
                                {:error, _} -> 
                                    {task |> failed_task, 
                                    [], process |> failed_process}
                            end
                        _ -> {task, [], process}
                    end
                else
                    {task, [], process}
                end
        end
    end
end
