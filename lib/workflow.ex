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

  def create(flow_type, context_params, opts \\ []) do
    created_by = Keyword.get(opts, :created_by, nil)
    Workflow.Engine.create_workflow(flow_type, %{flow_type: flow_type |> to_string, created_by_id: created_by}, context_params, opts)
  end

  def step(task, opts \\ []) do
    Workflow.Engine.step(task, opts)
  end

  def process_user_action(task, context_params, opts \\ []) do
    Workflow.Engine.process_user_action(task, context_params, opts)
  end
  
  def context_changeset(context, params, fields, validations) do
    Workflow.Engine.context_changeset(context, params, fields, validations)
  end
end
