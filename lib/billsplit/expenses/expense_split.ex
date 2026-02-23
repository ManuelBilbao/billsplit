defmodule Billsplit.Expenses.ExpenseSplit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "expense_splits" do
    field :amount, :integer

    belongs_to :expense, Billsplit.Expenses.Expense
    belongs_to :user, Billsplit.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(expense_split, attrs) do
    expense_split
    |> cast(attrs, [:amount, :expense_id, :user_id])
    |> validate_required([:amount, :expense_id, :user_id])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:expense_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:expense_id, :user_id])
  end
end
