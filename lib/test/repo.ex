defmodule Workflow.Test.Repo do
  use Ecto.Repo, otp_app: :workflow, adapter: Ecto.Adapters.Postgres
end
