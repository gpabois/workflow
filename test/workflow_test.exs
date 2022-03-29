defmodule Workflow.Test do
  use ExUnit.Case
  use Oban.Testing, repo: Workflow.Repo

  alias Workflow.Builder, as: B

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

  def assert_task_step(task) do
    {:ok, result} = Workflow.Engine.step task, schedule: false
    result
  end

  describe "test workflow nodes" do
    test "test flow node: start" do
      Workflow.register_flow B.begin("end") |> B.build("test")

      {:ok, {_process, %{flow_node_name: "start"}  = start_task}} = Workflow.create_if_ok "test",
      fn _process ->
        {:ok, %{}}
      end,
      schedule: false

      assert {%{status: "finished"}, [%{flow_node_name: "end"}], _process} = assert_task_step(start_task)
    end

    test "test flow node: end" do
      Workflow.register_flow B.begin("end") |> B.build("test")

      {:ok, {_process, %{flow_node_name: "start"}  = start_task}} = Workflow.create_if_ok "test",
      fn _process ->
        {:ok, %{}}
      end,
      schedule: false

      assert {%{status: "finished"}, [end_task], _process}      = assert_task_step(start_task)
      assert {%{status: "finished"}, [], %{status: "finished"}} = assert_task_step(end_task)
    end

    test "test flow node: user_action" do
      user = Workflow.Test.User.fixture()
      
      Workflow.register_flow B.begin("user_action") 
      |> B.user_action(
          "user_action",
          fn _task -> "test_view" end,
          fn _task -> user.id end,
          "end"
      ) |> B.build("test")

      {:ok, {_process, %{flow_node_name: "start"}  = start_task}} = Workflow.create_if_ok "test",
      fn _process ->
        {:ok, %{}}
      end,
      schedule: false

      assert {%{status: "finished"}, [user_action_task], _} = assert_task_step(start_task)

      # Should idling once it has been created
      assert {%{status: "idling", assigned_to_id: user_id} = user_action_task, [], _} = assert_task_step(user_action_task)
      
      # Should have been correctly assigned to the user
      assert user_id == user.id

      # Should still idling if we step it
      assert {%{status: "idling"} = user_action_task, [], _} = assert_task_step(user_action_task)

      # We execute done_if_ok to trigger the user action's node state to done, so it can be processed
      assert {:ok, %{status: "done"} = user_action_task} = Workflow.done_if_ok user_action_task, fn _ -> {:ok, %{}} end
      
      # Finish the task properly
      assert {%{status: "finished"}, [%{flow_node_name: "end"}], _} = assert_task_step(user_action_task)
    end

    test "test flow node: condition when is true" do
      Workflow.register_flow B.begin("condition") 
      |> B.condition(
          "condition",
          fn _ -> true end,
          "if",
          "else"
      ) |> B.job("if", fn _ -> :ok end, "end")
      |> B.job("else", fn _ -> :ok end, "end")
      |> B.build("test")

      {:ok, {_process, start_task}} = Workflow.create_if_ok "test",
      fn _process ->
        {:ok, %{}}
      end,
      schedule: false

      assert {%{status: "finished"}, [cond_task], _} = assert_task_step(start_task)
      assert {%{status: "finished"}, [%{flow_node_name: "if"}], _} = assert_task_step(cond_task)
    end

    test "test flow node: condition when is false" do
      Workflow.register_flow B.begin("condition") 
      |> B.condition(
          "condition",
          fn _ -> false end,
          "if",
          "else"
      ) |> B.job("if", fn _ -> :ok end, "end")
      |> B.job("else", fn _ -> :ok end, "end")
      |> B.build("test")

      {:ok, {_process, start_task}} = Workflow.create_if_ok "test",
      fn _process ->
        {:ok, %{}}
      end,
      schedule: false

      assert {%{status: "finished"}, [cond_task], _} = assert_task_step(start_task)
      assert {%{status: "finished"}, [%{flow_node_name: "else"}], _} = assert_task_step(cond_task)
    end
  end
end
