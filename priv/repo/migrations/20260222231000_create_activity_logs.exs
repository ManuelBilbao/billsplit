defmodule Billsplit.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs) do
      add :action, :string, null: false
      add :description, :string, null: false
      add :group_id, references(:groups, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:activity_logs, [:group_id])
  end
end
