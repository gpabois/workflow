import Config

import_config "#{Mix.env()}.exs"

config :workflow, Oban,
  prefix: "workflow",
  repo: Workflow.Repo,
  queues: [default: 10]
