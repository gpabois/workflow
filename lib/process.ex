defmodule Workflow.Process do
    use Ecto.Schema
    import Ecto.Changeset

    schema "workflow_processes" do
        Ecto.Schema.field :flow_type, :string, null: false
        Ecto.Schema.field :status, :string, default: "created"
        Ecto.Schema.field :created_at, :naive_datetime
        Ecto.Schema.field :finished_at, :naive_datetime
    end

    def creation_changeset(%__MODULE__{} = process, attrs) do
        process
        |> cast(attrs, [:flow_type, :created_at])
        |> put_change(:created_at, NaiveDatetime.utc_now())
        |> validate_required([:flow_type, :created_at])
    end

    def update_changeset(%__MODULE__{} = process, attrs) do
        process
        |> cast(attrs, [:status, :finished_at])
    end
end
