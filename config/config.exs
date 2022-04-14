import Config

config :workflow,
 ecto_repos: [Workflow.Repo],
 repo: Workflow.Repo

config :workflow, Oban,
  repo: Workflow.Repo,
  queues: [default: 10]

import_config "#{Mix.env()}.exs"