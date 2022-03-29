defmodule Workflow.Test.TestWorkflowContext do
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  alias Workflow.Repo

  schema "workflow_contexts" do
    belongs_to :process, Workflow.Process
    field :approved, :boolean, default: false
    belongs_to :approved_by, Workflow.Test.User
  end

  def creation_changeset(%__MODULE__{} = ctx, params) do
    ctx
    |> cast(params, [:process_id, :approved_by_id])
    |> validate_required([:process_id, :approved_by_id])
  end

  def update_changeset(%__MODULE__{} = ctx, params) do
    ctx
    |> cast(params, [:approved])
  end

  def get_by_process_id(process_id) do
    from(ctx in __MODULE__, where: ctx.process_id == ^process_id) |> Repo.one()
  end

  def fixture(params) do
    params = params
    |> Enum.into(%{
      approved_by_id: Workflow.Test.User.fixture().id,
    })

    {:ok, context} = %__MODULE__{} 
    |> creation_changeset(params) 
    |> Repo.insert()

    context
  end
end
