import Config

config :workflow, Workflow.Repo,
  username: "postgres",
  password: "postgres",
  database: "workflow_dev",
  hostname: "localhost"

config :phoenix, :json_library, Jason

config :workflow,
  user_model: Workflow.Test.User,
  user_table: :users
