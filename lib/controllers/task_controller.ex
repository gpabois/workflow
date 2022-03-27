defmodule Workflow.TaskController do
  use Phoenix.Controller

  @repo Application.fetch_env!(:workflow, :repo)

  def action(conn, %{"task_id" => task_id}) do
    task = @repo.get(Workflow.Task, task_id)
    case Workflow.Task.get_flow_node(task) do
      %Workflow.Flow.Nodes.UserAction{view_url_fn: view_url_fn} ->
        conn
        |> redirect(view_url_fn.(task))
        |> halt()
    end
  end
end
