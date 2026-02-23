defmodule Billsplit.ActivityLogs.ActivityLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_logs" do
    field :action, :string
    field :description, :string
    field :metadata, :map, default: %{}

    belongs_to :group, Billsplit.Groups.Group

    timestamps(type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:action, :description, :group_id, :metadata])
    |> validate_required([:action, :description, :group_id])
    |> foreign_key_constraint(:group_id)
  end
end
