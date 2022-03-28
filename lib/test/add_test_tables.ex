defmodule Worfklow.Test.Migrations.AddTestTables do
  use Ecto.Migration

  def change() do
    create table "users" do
      add :name, :string
    end

    Oban.Migrations.up()
    Workflow.Migrations.change()
   
    create table "workflow_contexts" do
      add :process_id, references("workflow_processes")
      add :approved_by_id, references("users")
      add :approved, :boolean
    end
  end
end
