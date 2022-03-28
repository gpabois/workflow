import Config

import_config "#{Mix.env()}.exs"

config :workflow,
 ecto_repos: [Workflow.Repo]

config :workflow, Oban,
  repo: Workflow.Repo,
  queues: [default: 10]
