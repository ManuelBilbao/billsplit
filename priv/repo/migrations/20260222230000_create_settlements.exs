defmodule Billsplit.Repo.Migrations.CreateSettlements do
  use Ecto.Migration

  def change do
    create table(:settlements) do
      add :amount, :integer, null: false
      add :date, :date, null: false
      add :group_id, references(:groups, on_delete: :delete_all), null: false
      add :from_id, references(:users, on_delete: :restrict), null: false
      add :to_id, references(:users, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:settlements, [:group_id])
  end
end
