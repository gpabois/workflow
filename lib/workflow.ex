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
    Workflow.Engine.create_workflow(%{flow_type: flow_type |> to_string, created_by_id: created_by}, context_params, opts)
  end

  def process_user_action(task, context_change_fn, opts \\ []) do
    Workflow.Engine.task_done_if_ok(task, context_change_fn, opts)
  end
  
  def context_changeset(context, params, node) do
    changeset = {context, node.types}
    |> Ecto.Changeset.cast(params, node.fields)
    
    for validation <- node.validations do
        validation.(changeset)
    end
  end
end
