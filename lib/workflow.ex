defmodule Workflow do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      Workflow.Repo,
      {Phoenix.PubSub, name: :workflow},
      {Oban, Application.fetch_env!(:workflow, Oban)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def create_if_ok(flow_type, context_fn) do
    Workflow.Engine.create_workflow_if_ok(%{flow_type: flow_type |> to_string}, context_fn)
  end

  def done_if_ok(task, context_change_fn) do
    Workflow.Engine.task_done_if_ok(task, context_change_fn)
  end
end
