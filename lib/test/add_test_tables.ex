defmodule Worfklow.Test.Migrations.AddTestTables do
  use Ecto.Migration

  def change() do
    create table "users" do
      add :name, :string
    end

    create table "workflow_contexts" do
      add :approved_by, references("users")
      add :approved, :boolean
    end

    Workflow.Migrations.change()
  end
end
