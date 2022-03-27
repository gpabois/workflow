defmodule Workflow.Task do
    use Ecto.Schema
    import Ecto.Query
    import Ecto.Changeset

    @repo Application.fetch_env!(:workflow, :repo)

    schema "workflow_tasks" do
        belongs_to :process, Workflow.Process
        belongs_to :assigned_to, Application.fetch_env!(:workflow, :user_model)
        field :flow_node_name, :string
        field :status, :string, default: "created"
        field :status_complement, :string, default: ""
        field :started_at, :naive_datetime
        field :finished_at, :naive_datetime
    end

    def creation_changeset(%__MODULE__{} = task, attrs) do
        task
        |> cast(attrs, [:process_id, :flow_node_name])
        |> validate_required([:process_id, :flow_node_name])
    end

    def update_changeset(%__MODULE__{} = task, attrs) do
        task
        |> cast(attrs, [:status, :status_complement, :finished_at])
    end

    def to_process() do
        from(task in __MODULE__, where: task.status in ["created", "done"]) |> @repo.all
    end

    @spec get_flow_node(
            atom
            | %{:flow_node_name => any, :process_id => any, optional(any) => any}
          ) :: any
    def get_flow_node(task) do
        process = @repo.get(Workflow.Process, task.process_id)
        flow = Workflow.Flow.get_flow(process.flow_type)
        Workflow.Flow.get_flow_node(flow, task.flow_node_name)
    end

end
