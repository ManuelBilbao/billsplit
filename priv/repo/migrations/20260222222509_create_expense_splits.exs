defmodule Billsplit.Repo.Migrations.CreateExpenseSplits do
  use Ecto.Migration

  def change do
    create table(:expense_splits) do
      add :amount, :integer, null: false
      add :expense_id, references(:expenses, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:expense_splits, [:expense_id])
    create index(:expense_splits, [:user_id])
    create unique_index(:expense_splits, [:expense_id, :user_id])
  end
end
