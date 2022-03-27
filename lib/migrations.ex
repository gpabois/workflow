defmodule Workflow.Migrations do
  use Ecto.Migration

  def change() do
    create table(:workflow_processes) do
      add :flow_type, :string, null: false
      add :status, :string, null: false
      add :created_at, :naive_datetime
      add :finished_at, :naive_datetime
    end

    create table(:workflow_tasks) do
      add :assign_to_id, references(Application.fetch_env!(:workflow, :user_table), on_delete: :delete_all)
      add :process, references(:workflow_processes, on_delete: :delete_all)

      add :flow_node_name, :string, null: false
      add :status, :string, null: false
      add :status_complement, :string
      add :started_at, :naive_datetime
      add :finished_at, :naive_datetime
    end
  end
end
