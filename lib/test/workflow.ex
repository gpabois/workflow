defmodule Workflow.Test.TestWorkflow do
  @behaviour Workflow.Flow

  alias Workflow.Flow.Builder, as: B
  alias Workflow.Test.TestWorkflowContext

  def get_flow() do
    B.begin()
    |> B.start("approve")
    |> B.user_action(:end,
      "approve",
      fn _ -> "/test_view" end,
      fn _ -> &assign_approval/1 end
      )
    |> B.nend()
    |> B.build(__MODULE__)
  end

  def assign_approval(task) do
    %{approved_by_id: approved_by_id} = TestWorkflowContext.get_by_process_id(task.process_id)
    approved_by_id
  end

end
