defmodule Billsplit.Debts do
  alias Billsplit.Repo
  alias Billsplit.Expenses.Expense
  alias Billsplit.Settlements.Settlement
  import Ecto.Query

  @doc """
  Compute net balances for each user in a group.
  Positive = owed money (paid more than share), Negative = owes money.
  Settlements are factored in: from gets +amount (paid off debt), to gets -amount (received payment).
  """
  def compute_balances(group_id) do
    expenses =
      Expense
      |> where(group_id: ^group_id)
      |> Repo.all()
      |> Repo.preload([:payer, expense_splits: :user])

    balances =
      Enum.reduce(expenses, %{}, fn expense, acc ->
        # Payer gets positive credit for what they paid
        acc = Map.update(acc, expense.payer_id, expense.amount, &(&1 + expense.amount))

        # Each split user owes their share (negative)
        Enum.reduce(expense.expense_splits, acc, fn split, acc2 ->
          Map.update(acc2, split.user_id, -split.amount, &(&1 - split.amount))
        end)
      end)

    settlements =
      Settlement
      |> where(group_id: ^group_id)
      |> Repo.all()

    balances =
      Enum.reduce(settlements, balances, fn settlement, acc ->
        # from paid off debt, so their balance goes up (less negative)
        acc = Map.update(acc, settlement.from_id, settlement.amount, &(&1 + settlement.amount))
        # to received payment, so their balance goes down (less positive)
        Map.update(acc, settlement.to_id, -settlement.amount, &(&1 - settlement.amount))
      end)

    balances
  end

  @doc """
  Returns simplified settlements as a list of {from_id, to_id, amount} tuples.
  Uses greedy algorithm: match largest debtor with largest creditor.
  """
  def simplify_debts(group_id) do
    balances = compute_balances(group_id)

    {debtors, creditors} =
      balances
      |> Enum.reduce({[], []}, fn {user_id, balance}, {debtors, creditors} ->
        cond do
          balance < 0 -> {[{user_id, -balance} | debtors], creditors}
          balance > 0 -> {debtors, [{user_id, balance} | creditors]}
          true -> {debtors, creditors}
        end
      end)

    debtors = Enum.sort_by(debtors, &elem(&1, 1), :desc)
    creditors = Enum.sort_by(creditors, &elem(&1, 1), :desc)

    settle(debtors, creditors, [])
  end

  defp settle([], _creditors, settlements), do: Enum.reverse(settlements)
  defp settle(_debtors, [], settlements), do: Enum.reverse(settlements)

  defp settle([{debtor_id, debt} | rest_debtors], [{creditor_id, credit} | rest_creditors], settlements) do
    amount = min(debt, credit)
    settlement = %{from_id: debtor_id, to_id: creditor_id, amount: amount}

    remaining_debt = debt - amount
    remaining_credit = credit - amount

    debtors = if remaining_debt > 0, do: [{debtor_id, remaining_debt} | rest_debtors], else: rest_debtors
    creditors = if remaining_credit > 0, do: [{creditor_id, remaining_credit} | rest_creditors], else: rest_creditors

    settle(debtors, creditors, [settlement | settlements])
  end
end
