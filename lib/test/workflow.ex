defmodule Workflow.Test.Flow do
  @behaviour Workflow.Flow

  alias Workflow.Flow.Builder, as: B

  def get_flow() do
    B.begin()
    |> B.start(:test_action)
    |> B.user_action(:end,
      :test_action,
      fn _ -> "/test_view" end,
      fn _ -> "user" end
      )
    |> B.nend()
    |> B.build(__MODULE__)
  end
end
