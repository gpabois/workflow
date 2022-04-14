defmodule Workflow.ProcessController do
    use Phoenix.Controller, namespace: Workflow

    alias Workflow.{Task, Flow}

    def new(conn, %{"flow_type" => flow_type} = _args) do
        flow = Flow.get_flow(flow_type)
        fields = Flow.get_flow_node(flow, "start")

        conn
        |> put_view(node.view)
        |> render("new.html", changeset: Workflow.context_changeset(%{}, %{}, fields), fields)
    end

    def create(conn, %{"flow_type" => flow_type, "context" => context_params} = _args) do
        flow = Flow.get_flow(flow_type)
        node = Flow.get_flow_node(flow, "start")
        
        case Workflow.create task, context_params do
            {:ok, {process, task}} -> 
            {:error, changeset} ->
                conn
                |> put_view(start.view)
                |> render("new.html", changeset: Workflow.context_changeset(%{}, %{}, fields), fields: fields)                
        end
    end
end