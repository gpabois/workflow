defmodule Workflow.Test do
  use ExUnit.Case
  use Oban.Testing, repo: Workflow.Repo

  alias Workflow.Test.{TestWorkflow, TestWorkflowContext}

  @repo_options Application.get_env(:workflow, Workflow.Test.Repo)

  setup_all do
    {:ok, _pid} = start_supervised(Workflow)

    Ecto.Migrator.up(Workflow.Repo, 0, Worfklow.Test.Migrations.AddTestTables)

    on_exit fn ->
      Ecto.Migrator.down(Workflow.Repo, 0, Worfklow.Test.Migrations.AddTestTables)
      :ok
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Workflow.Repo)
  end


  test "simple workflow" do
    Phoenix.PubSub.subscribe :workflow, "task"

    user = Workflow.Test.User.fixture()

    assert {:ok, process} = Workflow.create_if_ok TestWorkflow, 
      fn process -> 
        {:ok, TestWorkflowContext.fixture(process_id: process.id, approved_by_id: user.id)}
      end
    
      assert [task] = Workflow.Task.get_tasks_by_process_id(process.id)
      assert_enqueued worker: Workflow.Engine, args: %{id: task.id}
      assert %{success: 1, failure: 0} = Oban.drain_queue(queue: :workflow)

      task_id = task.id
      assert_receive {:finished, task_id}, 3_000

      assert [task] = Workflow.Task.get_assigned_tasks(user.id)

  end
end
