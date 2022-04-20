defmodule Workflow.TaskController do

    defmacro __using__(opts \\ []) do
        redirect_fn = Keyword.fetch!(opts, :redirect)
        quote do
            alias Workflow.{Process, Task, Flow}

            def prepare_user_action(conn, %{"task_id" => task_id} = _args) do
                task = Task.get(task_id)
                process = Process.get(task.process_id)
                node = Task.get_flow_node(task)

                conn
                |> put_view(node.view)
                |> render(
                    "user_action.html", 
                    changeset: Workflow.context_changeset(%{}, %{}, node.fields, node.validations),
                    task: task,
                    fields: node.fields
                )
            end

            def process_user_action(conn, %{"task_id" => task_id, "user_action" => user_action_params} = _args) do
                task = Task.get(task_id)
                process = Process.get(task.process_id)
                node = Task.get_flow_node(task)
                
                case Workflow.process_user_action(task, user_action_params) do
                    {:ok, task} -> 
                        conn
                        |> redirect(to: unquote(redirect_fn).(conn, task, process))

                    {:error, changeset} ->
                        conn
                        |> put_view(node.view)
                        |> render("user_action", changeset: changeset, task: task, fields: node.fields)                
                end
            end
        end
    end
end