defmodule Workflow.Task do
    use Ecto.Schema
    import Ecto.Query
    import Ecto.Changeset

    @repo Workflow.Repo

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

    def get_tasks_by_process_id(process_id) do
        from(t in __MODULE__, where: t.process_id == ^process_id) |> @repo.all()
    end

    def get_assigned_tasks(user_id) do
        from(t in __MODULE__, where: t.assigned_to_id == ^user_id) |> @repo.all()
    end

    def get_flow_node(task) do
        process = @repo.get(Workflow.Process, task.process_id)
        flow = Workflow.Flow.get_flow(process.flow_type)
        Workflow.Flow.get_flow_node(flow, task.flow_node_name)
    end

end
