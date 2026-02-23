defmodule Billsplit.Repo.Migrations.CreateExpenses do
  use Ecto.Migration

  def change do
    create table(:expenses) do
      add :description, :string, null: false
      add :amount, :integer, null: false
      add :date, :date, null: false
      add :split_type, :string, null: false, default: "equal"
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :payer_id, references(:users, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:expenses, [:group_id])
    create index(:expenses, [:payer_id])
  end
end
