defmodule Workflow.Test.User do
  use Ecto.Schema

  schema "users" do
    field :name, :string
  end


  def user_fixture() do
    {:ok, user} = %__MODULE__{name: Faker.Person.first_name()} |> Workflow.Test.Repo.insert()
    user
  end

end
