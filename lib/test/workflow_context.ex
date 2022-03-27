defmodule Workflow.Test.Workflow.Context do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias Workflow.Test.Repo

  schema "workflow_contexts" do
    belongs_to :process, Workflow.Process
    field :approved, :boolean, default: false
    belongs_to :approved_by, Workflow.Test.User
  end

  def creation_changeset(%__MODULE__{} = ctx, params) do
    ctx
    |> cast(params, [:process_id, :approved_by])
    |> validate_required([:process_id, :approved_by])
  end

  def get_by_process_id(process_id) do
    from(ctx in __MODULE__, where: ctx.process_id == ^process_id) |> Repo.one()
  end

end
