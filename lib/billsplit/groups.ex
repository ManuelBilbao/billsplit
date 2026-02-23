defmodule Billsplit.Groups do
  import Ecto.Query
  alias Billsplit.Repo
  alias Billsplit.Groups.{Group, GroupMember}
  alias Billsplit.Accounts

  def list_groups do
    Group
    |> order_by(desc: :updated_at)
    |> Repo.all()
    |> Repo.preload([:members, :expenses])
  end

  def get_group!(id) do
    Group
    |> Repo.get!(id)
    |> Repo.preload([:members, :expenses])
  end

  def create_group(attrs) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  def change_group(%Group{} = group, attrs \\ %{}) do
    Group.changeset(group, attrs)
  end

  def add_member(group_id, user_name) do
    with {:ok, user} <- Accounts.find_or_create_user(user_name) do
      %GroupMember{}
      |> GroupMember.changeset(%{group_id: group_id, user_id: user.id})
      |> Repo.insert()
    end
  end

  def remove_member(group_id, user_id) do
    case Repo.get_by(GroupMember, group_id: group_id, user_id: user_id) do
      nil -> {:error, :not_found}
      member -> Repo.delete(member)
    end
  end

  def list_members(group_id) do
    GroupMember
    |> where(group_id: ^group_id)
    |> preload(:user)
    |> Repo.all()
    |> Enum.map(& &1.user)
  end

  def group_stats(group) do
    total_expenses =
      group.expenses
      |> Enum.reduce(0, fn e, acc -> acc + e.amount end)

    %{
      member_count: length(group.members),
      expense_count: length(group.expenses),
      total_expenses: total_expenses
    }
  end
end
