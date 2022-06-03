defmodule Workflow.TaskController do

    defmacro __using__(opts \\ []) do
        redirect_fn = Keyword.fetch!(opts, :redirect)
        quote do
            alias Workflow.{Process, Task, Flow}

             def prepare_user_action(conn, %{"task_id" => task_id} = _args) do
                task = Task.get(task_id)
                process = Process.get(task.process_id)
                node = Task.get_flow_node(task)

                def_ctx_extractor = fn ctx -> [] end
                
                {view, action, ctx_extractor} = case node.view do
                    {view, action, ctx_extractor} -> {view, action, ctx_extractor}
                    {view, action} -> {view, action, def_ctx_extractor}
                    view -> {view, "user_action.html", def_ctx_extractor}
                end
                
                assigns = [
                    changeset: Workflow.context_changeset(%{}, %{}, node.fields, node.validations),
                    context: process.context,
                    task: task,
                    fields: node.fields
                ] ++ ctx_extractor.(process.context)

                conn
                |> put_view(view)
                |> render(
                    action, 
                    assigns
                )
            end

            def process_user_action(conn, %{"task_id" => task_id, "user_action" => user_action_params} = _args) do
                task = Task.get(task_id)
                process = Process.get(task.process_id)
                node = Task.get_flow_node(task)
                
                def_ctx_extractor = fn ctx -> [] end
                
                {view, action, ctx_extractor} = case node.view do
                    {view, action, ctx_extractor} -> {view, action, ctx_extractor}
                    {view, action} -> {view, action, def_ctx_extractor}
                    view -> {view, "user_action.html", def_ctx_extractor}
                end

                assigns = [
                    changeset: Workflow.context_changeset(%{}, %{}, node.fields, node.validations),
                    context: process.context,
                    task: task,
                    fields: node.fields
                ] ++ ctx_extractor.(process.context)

                case Workflow.process_user_action(task, user_action_params) do
                    {:ok, task} -> 
                        conn
                        |> redirect(to: unquote(redirect_fn).(conn, task, process))

                    {:error, changeset} ->
                        conn
                        |> put_view(view)
                        |> render(action, assigns)                
                end
            end
        end
    end
end