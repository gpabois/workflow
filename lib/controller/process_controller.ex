defmodule Workflow.ProcessController do

    def __using__(opts \\ []) do
        redirect_fn = Keyword.fetch!(opts, :redirect)
        quote do
            alias Workflow.{Task, Flow}

            def new(conn, %{"flow_type" => flow_type} = _args) do
                flow = Flow.get_flow(flow_type)
                node = Flow.get_flow_node(flow, "start")

                conn
                |> put_view(node.view)
                |> render("new.html", changeset: Workflow.context_changeset(%{}, %{}, node.fields, node.validations), fields: node.fields)
            end

            def create(conn, %{"flow_type" => flow_type, "context" => context_params} = _args) do
                flow = Flow.get_flow(flow_type)
                node = Flow.get_flow_node(flow, "start")
                
                case Workflow.create(flow_type, context_params) do
                    {:ok, {process, task}} -> 
                        conn
                        |> redirect(conn, to: unquote(redirect_fn.(quote do process end)))

                    {:error, changeset} ->
                        conn
                        |> put_view(start.view)
                        |> render("new.html", changeset: Workflow.context_changeset(%{}, %{}, node.fields, node.validations), fields: fields)                
                end
            end
        end
    end
end