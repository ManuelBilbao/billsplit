defmodule Billsplit.Groups.GroupMember do
  use Ecto.Schema
  import Ecto.Changeset

  schema "group_members" do
    belongs_to :group, Billsplit.Groups.Group
    belongs_to :user, Billsplit.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(group_member, attrs) do
    group_member
    |> cast(attrs, [:group_id, :user_id])
    |> validate_required([:group_id, :user_id])
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:group_id, :user_id])
  end
end
