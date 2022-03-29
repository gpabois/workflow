defmodule Workflow.Test.TestWorkflow do
  @behaviour Workflow.Flow

  alias Workflow.Flow.Builder, as: B
  alias Workflow.Test.TestWorkflowContext

  def get_flow() do
    B.begin()
    |> B.start("approve")
    |> B.user_action("approve",
      fn _ -> "/test_view" end,
      &assign_approval/1,
      "check_approval"
      )
    |> B.condition("check_approval", &check_approval?/1, "end", "reject") 
    |> B.job("reject", &reject/1, "end")
    |> B.nend()
    |> B.build(__MODULE__)
  end

  def reject(task) do
  end

  def assign_approval(task) do
    %{approved_by_id: approved_by_id} = TestWorkflowContext.get_by_process_id(task.process_id)
    approved_by_id
  end

  def check_approval?(task) do
    %{approved: approved} = TestWorkflowContext.get_by_process_id(task.process_id)
    approved
  end

end
