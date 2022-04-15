defmodule Workflow.Migrations do
  use Ecto.Migration

  def change() do
    #Oban.Migrations.up()

    create table(:workflow_processes) do
      add :created_by_id, references(Application.fetch_env!(:workflow, :user_table), on_delete: :delete_all)
      add :flow_type, :string, null: false
      add :status, :string, null: false
      add :created_at, :naive_datetime
      add :finished_at, :naive_datetime
      add :context, :map, default: %{}
    end

    execute("CREATE INDEX workflow_processes_contexts ON workflow_processes USING GIN(context)")

    create table(:workflow_tasks) do
      add :assigned_to_id, references(Application.fetch_env!(:workflow, :user_table), on_delete: :delete_all)
      add :process_id, references(:workflow_processes, on_delete: :delete_all), null: false
      add :parent_task_id, references(:workflow_tasks)
      add :subprocess_id, references(:workflow_processes)

      add :flow_node_name, :string, null: false
      add :status, :string, null: false
      add :status_complement, :string
      add :started_at, :naive_datetime
      add :finished_at, :naive_datetime
    end
  end

  def down do
    Oban.Migrations.down()
  end
end
