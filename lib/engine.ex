defmodule Workflow.Engine do
    use Oban.Worker, queue: :workflow

    @repo Application.fetch_env!(:workflow, :repo)

    alias Workflow.{Process, Task}

    def create_workflow_if_ok(process_params, context_fn) do
        process_changeset = Process.creation_changeset %Process{}, process_params

        @repo.transaction fn ->
            with {:ok, process} <- @repo.insert(process_changeset),
                 {:ok, _context} <- @repo.insert(context_fn.(process)),
                 {:ok, _task}    <- create_task(%{process_id: process.id, flow_node_name: :start})
            do
                {:ok, process}
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
        |> Workflow.Engine.new(queue: :workflow)
        |> Oban.insert()
    end

    defp create_task(task_params) do
        task_params = task_params
        |> Map.put(:status, "created")
        |> Map.put(:started_at, NaiveDateTime.utc_now())

        @repo.transaction(fn ->
            with {:ok, task} <- Task.creation_changeset(%Task{}, task_params) |> @repo.insert(),
                    {:ok, _} <- schedule_task(task)
            do
                task
            else
                {:error, error} -> error
            end
        end)
    end

    defp close_task(task) do
        Task.update_changeset(task, %{status: "finished", finished_at: NaiveDateTime.utc_now()})
        |> @repo.update()
    end

    defp close_process(process) do
        Process.update_changeset(process, %{status: "finished", finished_at: NaiveDateTime.utc_now()})
        |> @repo.update()
    end

    @impl Oban.Worker
    def perform(%Oban.Job{args: %{"id" => task_id}}) do
        task = @repo.get(Task, task_id)
        process = @repo.get(Process, task.process_id)

        @repo.transaction fn -> step(task, process) end
    end

    defp step(%{flow_node_name: flow_node_name} = task, process) do
        flow =  Workflow.Flow.get_flow(process.flow_type)
        flow_node =  Workflow.Flow.get_flow_node(flow, flow_node_name)

        case flow_node do
            %Workflow.Flow.Nodes.Start{next: next_node} ->
                create_task(%{
                    process_id: process.id,
                    flow_node_name: next_node
                })
                close_task(task)

            %Workflow.Flow.Nodes.End{} ->
                close_task(task)
                close_process(process)

            %Workflow.Flow.Nodes.Condition{predicate: predicate?, if_node: if_node, else_node: else_node} ->
                next_node = if(predicate?.(task), do: if_node, else: else_node)

                create_task(%{
                    process_id: process.id,
                    flow_node_name: next_node
                })

                close_task(task)

            %Workflow.Flow.Nodes.UserAction{assign_user_fn: assign_user_fn, next: next_node} ->
                case task.status do
                    "created" ->
                        Task.update_changeset(task, %{
                            assigned_to_id: assign_user_fn.(task),
                            status: "idling"
                        })
                        |> @repo.update()
                    "done" ->
                        create_task(%{
                            process_id: process.id,
                            flow_node_name: next_node
                        })

                        close_task(task)
                end

            %Workflow.Flow.Nodes.Job{work_fn: work_fn, next: next_node} ->
                case work_fn.(task) do
                    _ -> create_task(%{
                        process_id: process.id,
                        flow_node_name: next_node
                    })
                    close_task(task)
                end
        end
        :ok
    end
end
