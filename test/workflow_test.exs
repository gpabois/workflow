defmodule Workflow.Test do
  use ExUnit.Case

  alias Workflow.Test.Repo

  @repo_options Application.get_env(:workflow, Workflow.Test.Repo)

  setup_all do
    start_supervised({Repo, @repo_options})
    Ecto.Migrator.run(Repo, [{0, Worfklow.Test.Migrations.AddTestTables}], :up, all: true)

    on_exit fn ->
      Ecto.Migrator.run(Repo, [{0, Worfklow.Test.Migrations.AddTestTables}], :down, all: true)
      stop_supervised(Repo)
      :ok
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end


  test "simple workflow" do

  end
end
