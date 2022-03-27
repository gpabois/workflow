defmodule Worfklow.Test.Migrations.AddTestTables do
  use Ecto.Migration

  def change() do
    create table "users" do
      add :name, :string
    end

    Workflow.Migrations.change()
  end
end
