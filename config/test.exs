import Config

config :workflow, Workflow.Test.Repo,
  username: "postgres",
  password: "postgres",
  database: "workflow_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :phoenix, :json_library, Jason

config :workflow,
  repo: Workflow.Test.Repo,
  ecto_repos: [Workflow.Test.Repo],
  user_model: Workflow.Test.User,
  user_table: :users
