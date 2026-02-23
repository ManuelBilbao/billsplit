defmodule Billsplit.Accounts do
  import Ecto.Query
  alias Billsplit.Repo
  alias Billsplit.Accounts.User

  def list_users do
    Repo.all(from u in User, order_by: u.name)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_name(name) do
    Repo.get_by(User, name: name)
  end

  def find_or_create_user(name) do
    name = String.trim(name)

    case get_user_by_name(name) do
      nil -> create_user(%{name: name})
      user -> {:ok, user}
    end
  end

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
