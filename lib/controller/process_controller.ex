defmodule Workflow.ProcessController do

    defmacro __using__(opts \\ []) do
        redirect_fn = Keyword.fetch!(opts, :redirect)
        quote do
            alias Workflow.{Process, Task, Flow}

            def show(conn, %{"process_id" => process_id}) do
                process = Process.get(process_id)
                flow    = Flow.get_flow(process.flow_type)
                node    = Flow.get_flow_node(flow, "start")   
               
                {view, action} = case node.view do
                    {view, action} -> {view, action}
                    _ -> {node.view, "show.html"}
                end
                
                conn
                |> put_view(view)
                |> render(action, process: process, tasks: Task.get_tasks_by_process_id(process.id), context: process.context)             
            end

            def new(conn, %{"flow_type" => flow_type} = _params) do
                flow = Flow.get_flow(flow_type)
                node = Flow.get_flow_node(flow, "start")

                {view, action} = case node.view do
                    {view, action} -> {view, action}
                    _ -> {node.view, "new.html"}
                end

                conn
                |> put_view(view)
                |> render(action, flow: flow, changeset: Workflow.context_changeset(%{}, %{}, node.fields, node.validations), fields: node.fields)
            end

            def create(conn, %{"flow_type" => flow_type, "initiate" => initiate_params} = _args) do
                flow = Flow.get_flow(flow_type)
                node = Flow.get_flow_node(flow, "start")
                
                created_by_id = case conn do
                    %{assigns: %{current_user: current_user}} -> current_user.id
                    _ -> nil
                end

                {view, action} = case node.view do
                    {view, action} -> {view, action}
                    _ -> {node.view, "new.html"}
                end

                case Workflow.create(flow_type, initiate_params, created_by: created_by_id) do
                    {:ok, {process, task}} -> 
                        conn
                        |> redirect(to: unquote(redirect_fn).(conn, process))

                    {:error, changeset} ->
                        conn
                        |> put_view(view)
                        |> render(action, changeset: changeset, fields: node.fields)                
                end
            end
        end
    end
end