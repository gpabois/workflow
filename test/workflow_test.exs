defmodule Workflow.Test do
  use ExUnit.Case

  alias Workflow.Test.Repo

  @repo_options Application.get_env(:workflow, Workflow.Test.Repo)

  setup do
    Repo.start_link(@repo_options)
    Ecto.Migrator.run(Repo, [{0, Worfklow.Test.Migrations.AddTestTables}], :up, all: true)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    on_exit fn ->
      #Repo.start_link(@repo_options)
      #Ecto.Migrator.run(Repo, [{0, Worfklow.Test.Migrations.AddTestTables}], :down, all: true)
      #Repo.stop()
      :ok
    end
  end


  test "simple workflow" do

  end
end
