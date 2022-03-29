defmodule Workflow.Test do
  use ExUnit.Case
  use Oban.Testing, repo: Workflow.Repo

  alias Workflow.Test.{TestWorkflow, TestWorkflowContext}
  alias Workflow.{Process, Task}


  setup_all do
    {:ok, _pid} = start_supervised(Workflow)

    Ecto.Migrator.up(Workflow.Repo, 0, Worfklow.Test.Migrations.AddTestTables)

    on_exit fn ->
      #Ecto.Migrator.down(Workflow.Repo, 0, Worfklow.Test.Migrations.AddTestTables)
      :ok
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Workflow.Repo)
  end

  test "test nodes" do
    user = Workflow.Test.User.fixture()

    {:ok, {process, start_task}} = Workflow.create_if_ok TestWorkflow,
      fn process ->
        {:ok, TestWorkflowContext.fixture(process_id: process.id, approved_by_id: user.id)}
      end,
      return_task: true,
      schedule: false
      
      assert %{flow_node_name: "start"} = start_task
      
      {:ok, {_task, [approve_task], _process}} = Workflow.Engine.step start_task, schedule: false
      
      assert %{flow_node_name: "approve"} = approve_task
      # Should assign the user 
      assert {:ok, {approve_task, [], _process}} = Workflow.Engine.step approve_task, schedule: false
      assert approve_task.assigned_to_id == user.id
  end
end
