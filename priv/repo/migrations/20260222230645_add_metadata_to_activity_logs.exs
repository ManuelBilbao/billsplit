defmodule Billsplit.Repo.Migrations.AddMetadataToActivityLogs do
  use Ecto.Migration

  def change do
    alter table(:activity_logs) do
      add :metadata, :map, default: %{}
    end
  end
end
