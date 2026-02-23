defmodule Billsplit.Settlements.Settlement do
  use Ecto.Schema
  import Ecto.Changeset

  schema "settlements" do
    field :amount, :integer
    field :date, :date

    belongs_to :group, Billsplit.Groups.Group
    belongs_to :from, Billsplit.Accounts.User
    belongs_to :to, Billsplit.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(settlement, attrs) do
    settlement
    |> cast(attrs, [:amount, :date, :group_id, :from_id, :to_id])
    |> validate_required([:amount, :date, :group_id, :from_id, :to_id])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:from_id)
    |> foreign_key_constraint(:to_id)
  end
end
