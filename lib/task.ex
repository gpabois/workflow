defmodule Workflow.Task do
    use Ecto.Schema
    import Ecto.Query
    import Ecto.Changeset

    @repo Workflow.Repo

    schema "workflow_tasks" do
        belongs_to :process, Workflow.Process
        belongs_to :assigned_to, Application.fetch_env!(:workflow, :user_model)
        has_one :subprocess, Workflow.Process
        field :flow_node_name, :string
        field :status, :string, default: "created"
        field :status_complement, :string, default: ""
        field :started_at, :naive_datetime
        field :finished_at, :naive_datetime
    end

    def creation_changeset(%__MODULE__{} = task, attrs) do
        attrs = attrs
        |> Map.put(:started_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
        
        task
        |> cast(attrs, [:process_id, :started_at, :flow_node_name])
        |> validate_required([:process_id, :started_at, :flow_node_name])
       end

    def update_changeset(%__MODULE__{} = task, attrs) do
        task
        |> cast(attrs, [:status, :assigned_to_id, :status_complement, :finished_at])
    end

    def get_subprocess_driver(subprocess_id) do
        from(t in __MODULE__, where: t.subprocess_id == ^subprocess_id, order_by: [desc: t.id]) |> @repo.all()
    end

    def get_tasks_by_process_id(process_id) do
        from(t in __MODULE__, where: t.process_id == ^process_id, order_by: [desc: t.id]) |> @repo.all()
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
