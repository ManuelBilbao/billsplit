defmodule Billsplit.Settlements do
  import Ecto.Query
  alias Billsplit.Repo
  alias Billsplit.Settlements.Settlement
  alias Billsplit.Debts
  alias Billsplit.ActivityLogs

  def create_settlement(attrs) do
    case %Settlement{}
         |> Settlement.changeset(attrs)
         |> Repo.insert() do
      {:ok, settlement} ->
        settlement = Repo.preload(settlement, [:from, :to])

        ActivityLogs.log(
          settlement.group_id,
          "settlement_created",
          "Payment recorded: #{settlement.from.name} → #{settlement.to.name} — #{ActivityLogs.format_amount(settlement.amount)}",
          %{
            from: settlement.from.name,
            to: settlement.to.name,
            amount: settlement.amount,
            date: Date.to_iso8601(settlement.date)
          }
        )

        {:ok, settlement}

      error ->
        error
    end
  end

  def create_settlements_from_debts(group_id) do
    debts = Debts.simplify_debts(group_id)
    today = Date.utc_today()

    results =
      Enum.map(debts, fn %{from_id: from_id, to_id: to_id, amount: amount} ->
        # Use direct insert to avoid double-logging each individual settlement
        %Settlement{}
        |> Settlement.changeset(%{
          amount: amount,
          group_id: group_id,
          from_id: from_id,
          to_id: to_id,
          date: today
        })
        |> Repo.insert()
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        settlements =
          results
          |> Enum.map(fn {:ok, s} -> s end)
          |> Repo.preload([:from, :to])

        count = length(settlements)

        if count > 0 do
          settlements_metadata =
            Enum.map(settlements, fn s ->
              %{from: s.from.name, to: s.to.name, amount: s.amount}
            end)

          ActivityLogs.log(
            group_id,
            "settle_all",
            "Settled all debts (#{count} #{if count == 1, do: "payment", else: "payments"})",
            %{settlements: settlements_metadata}
          )
        end

        {:ok, settlements}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def list_settlements(group_id) do
    Settlement
    |> where(group_id: ^group_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end
end
