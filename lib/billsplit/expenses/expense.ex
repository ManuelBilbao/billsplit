defmodule Billsplit.Expenses.Expense do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expenses" do
    field :description, :string
    field :amount, :integer
    field :date, :date
    field :split_type, :string, default: "equal"

    belongs_to :group, Billsplit.Groups.Group
    belongs_to :payer, Billsplit.Accounts.User
    has_many :expense_splits, Billsplit.Expenses.ExpenseSplit

    timestamps(type: :utc_datetime)
  end

  def changeset(expense, attrs) do
    expense
    |> cast(attrs, [:description, :amount, :date, :split_type, :group_id, :payer_id])
    |> validate_required([:description, :amount, :date, :split_type, :group_id, :payer_id])
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:split_type, ["equal", "custom"])
    |> foreign_key_constraint(:group_id)
    |> foreign_key_constraint(:payer_id)
  end
end
