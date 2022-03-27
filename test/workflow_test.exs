defmodule Workflow.Test do
  use ExUnit.Case

  alias Workflow.Test.Repo

  @repo_options Application.get_env(:workflow, Workflow.Test.Repo)

  setup_all do
    start_supervised({Repo, @repo_options})
    Ecto.Migrator.up(Repo, 0, Worfklow.Test.Migrations.AddTestTables)

    on_exit fn ->
      Repo.start_link(@repo_options)
      Ecto.Migrator.down(Repo, 0, Worfklow.Test.Migrations.AddTestTables)
      Repo.stop()
      :ok
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end


  test "simple workflow" do

  end
end
