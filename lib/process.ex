defmodule Workflow.Process do
    use Ecto.Schema
    import Ecto.Query
    import Ecto.Changeset

    schema "workflow_processes" do
        field :flow_type, :string, null: false
        field :status, :string, default: "created"
        belongs_to :created_by, Application.fetch_env!(:workflow, :user_model)
        field :created_at, :naive_datetime
        field :finished_at, :naive_datetime
        field :context, :map
    end

    def creation_changeset(%__MODULE__{} = process, attrs) do
        attrs = attrs
        |> Map.put(:created_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
        
        process
        |> cast(attrs, [:flow_type, :created_at, :context, :created_by_id])
        |> validate_required([:flow_type, :created_at, :context])
    end

    def update_changeset(%__MODULE__{} = process, attrs) do
        process
        |> cast(attrs, [:status, :finished_at, :context])
    end

    def get(id) do
        Workflow.Repo.get(__MODULE__, id)
    end

    def get_by_flow_type(flow_type) do
        from(p in __MODULE__, where: p.flow_type == ^flow_type) |> Workflow.Repo.all()
    end
end
