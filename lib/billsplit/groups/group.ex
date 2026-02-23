defmodule Billsplit.Groups.Group do
  use Ecto.Schema
  import Ecto.Changeset

  schema "groups" do
    field :name, :string
    field :description, :string

    has_many :group_members, Billsplit.Groups.GroupMember
    has_many :members, through: [:group_members, :user]
    has_many :expenses, Billsplit.Expenses.Expense

    timestamps(type: :utc_datetime)
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 200)
  end
end
