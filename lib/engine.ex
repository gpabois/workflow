defmodule Workflow.Engine do
    use Oban.Worker

    @repo Workflow.Repo

    alias Workflow.{Process, Task}
    alias Phoenix.PubSub

    def create_workflow_if_ok(process_params, context_fn, opts \\ []) do
        process_changeset = Process.creation_changeset %Process{}, process_params

        @repo.transaction fn ->
            with {:ok, process} <- @repo.insert(process_changeset),
                 {:ok, _context} <- context_fn.(process),
                 {:ok, task}    <- create_task(%{process_id: process.id, flow_node_name: "start"}, opts)
            do
                if Keyword.get(opts, :return_task, false) do
                    {process, task}
                else
                    process
                end
            else
                {:error, error} -> error
            end
        end
    end

    def task_done_if_ok(task, context_change_fn) do
        @repo.transaction fn ->
            with {:ok, _}    <- context_change_fn.(),
                 {:ok, task} <- Task.update_changeset(task, %{status: "done"}) |> @repo.update(),
                 {:ok, _}    <- schedule_task(task)
            do
                task
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

    defp close_task(task) do
        with {:ok, task} <- Task.update_changeset(task, %{status: "finished", finished_at: NaiveDateTime.utc_now()}) |> @repo.update()
        do
            PubSub.broadcast :workflow, "task", {:finished, task.id}
            {:ok, task}
        else
            {:error, error} -> 
                PubSub.broadcast :workflow, "task", {:error, task.id, error}
                {:error, error}
        end
    end

    defp close_process(process) do
        Process.update_changeset(process, %{status: "finished", finished_at: NaiveDateTime.utc_now()})
        |> @repo.update()
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
        flow =  Workflow.Flow.get_flow(process.flow_type)
        flow_node =  Workflow.Flow.get_flow_node(flow, flow_node_name)
        
        case flow_node do
            nil -> raise "Missing node #{flow_node_name} in workflow #{process.flow_type}"
            %Workflow.Flow.Nodes.Start{next: next_node} ->  
                with {:ok, next_task} <- create_task(%{process_id: process.id, flow_node_name: next_node}, opts),
                     {:ok, task} <- close_task(task) 
                do
                    {task, [next_task], process}
                end

            %Workflow.Flow.Nodes.End{} ->
                with {:ok, task} <- close_task(task),
                     {:ok, process} <- close_process(process) 
                do
                    {task, [], process}
                end

            %Workflow.Flow.Nodes.Condition{predicate: predicate?, if_node: if_node, else_node: else_node} ->
                next_node = if(predicate?.(task), do: if_node, else: else_node)

                with {:ok, next_task} <- create_task(%{process_id: process.id, flow_node_name: next_node}, opts),
                     {:ok, task} <- close_task(task)
                do
                    {task, [next_task], process}
                end

            %Workflow.Flow.Nodes.UserAction{assign_user_fn: assign_user_fn, next: next_node} ->
                case task.status do
                    "created" ->
                        with {:ok, task} <- Task.update_changeset(task, %{
                            assigned_to_id: assign_user_fn.(task),
                            status: "idling"
                        }) |> @repo.update() do
                            {task, [], process}
                        end
                    "idling" ->
                        {task, [], process}
                    "done" ->
                        with {:ok, next_task} <- create_task(%{process_id: process.id, flow_node_name: next_node}, opts),
                            {:ok, task} <- close_task(task)
                        do
                            {task, [next_task], process}
                        end
                    _ -> raise "Invalid state #{task.status}."
                end

            %Workflow.Flow.Nodes.Job{work_fn: work_fn, next: next_node} ->
                case work_fn.(task) do
                    _ -> 
                        with {:ok, next_task} <- create_task(%{process_id: process.id, flow_node_name: next_node}, opts),
                            {:ok, task} <- close_task(task)
                        do
                            {task, [next_task], process}
                        end
                end
        end
    end
end
