defmodule Billsplit.ActivityLogs do
  import Ecto.Query
  alias Billsplit.Repo
  alias Billsplit.ActivityLogs.ActivityLog

  def log(group_id, action, description, metadata \\ %{}) do
    %ActivityLog{}
    |> ActivityLog.changeset(%{
      group_id: group_id,
      action: action,
      description: description,
      metadata: metadata
    })
    |> Repo.insert()
  end

  def list_logs(group_id) do
    ActivityLog
    |> where(group_id: ^group_id)
    |> order_by([l], desc: l.inserted_at, desc: l.id)
    |> Repo.all()
  end

  @doc "Format cents as dollar string, e.g. 1050 -> \"$10.50\""
  def format_amount(cents) when is_integer(cents) do
    dollars = abs(cents) / 100
    "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end
end
