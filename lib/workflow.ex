defmodule Workflow do
  use Supervisor

  def start_link(flows \\ []) do
    Supervisor.start_link(__MODULE__, flows)
  end

  @impl true
  def init(flows \\ []) do
    children = [
      {Workflow.Registry, flows},
      Workflow.Repo,
      {Phoenix.PubSub, name: :workflow},
      {Oban, Application.fetch_env!(:workflow, Oban)}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def register_flow(flow) do
    Workflow.Registry.register(flow.name, flow)
  end

  def create_if_ok(flow_type, context_fn, opts \\ []) do
    Workflow.Engine.create_workflow_if_ok(%{flow_type: flow_type |> to_string}, context_fn, opts)
  end

  def done_if_ok(task, context_change_fn, opts \\ []) do
    Workflow.Engine.task_done_if_ok(task, context_change_fn, opts)
  end
end
