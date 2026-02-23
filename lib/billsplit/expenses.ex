defmodule Billsplit.Expenses do
  import Ecto.Query
  alias Billsplit.Repo
  alias Billsplit.Expenses.{Expense, ExpenseSplit}
  alias Billsplit.ActivityLogs
  alias Ecto.Multi

  def list_expenses(group_id) do
    Expense
    |> where(group_id: ^group_id)
    |> order_by(desc: :date, desc: :inserted_at)
    |> Repo.all()
    |> Repo.preload([:payer, expense_splits: :user])
  end

  def get_expense!(id) do
    Expense
    |> Repo.get!(id)
    |> Repo.preload([:payer, :group, expense_splits: :user])
  end

  def create_expense(attrs, split_data) do
    Multi.new()
    |> Multi.insert(:expense, Expense.changeset(%Expense{}, attrs))
    |> Multi.run(:splits, fn repo, %{expense: expense} ->
      insert_splits(repo, expense, attrs, split_data)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{expense: expense}} ->
        expense = Repo.preload(expense, [:payer, expense_splits: :user])

        splits_metadata =
          Enum.map(expense.expense_splits, fn s ->
            %{user: s.user.name, amount: s.amount}
          end)

        ActivityLogs.log(
          expense.group_id,
          "expense_created",
          "Expense added: \"#{expense.description}\" — #{ActivityLogs.format_amount(expense.amount)} (paid by #{expense.payer.name})",
          %{
            payer: expense.payer.name,
            amount: expense.amount,
            date: Date.to_iso8601(expense.date),
            split_type: attrs["split_type"] || attrs[:split_type] || "equal",
            splits: splits_metadata
          }
        )

        {:ok, expense}

      {:error, :expense, changeset, _} ->
        {:error, changeset}

      {:error, :splits, reason, _} ->
        {:error, reason}
    end
  end

  defp insert_splits(repo, expense, attrs, split_data) do
    case attrs["split_type"] || attrs[:split_type] || "equal" do
      "equal" ->
        insert_equal_splits(repo, expense, split_data.member_ids)

      "custom" ->
        insert_custom_splits(repo, expense, split_data.custom_splits)
    end
  end

  defp insert_equal_splits(repo, expense, member_ids) do
    count = length(member_ids)

    if count == 0 do
      {:error, "No members to split with"}
    else
      base = div(expense.amount, count)
      remainder = rem(expense.amount, count)

      splits =
        member_ids
        |> Enum.with_index()
        |> Enum.map(fn {user_id, index} ->
          amount = if index < remainder, do: base + 1, else: base

          %ExpenseSplit{}
          |> ExpenseSplit.changeset(%{
            amount: amount,
            expense_id: expense.id,
            user_id: user_id
          })
        end)

      results = Enum.map(splits, &repo.insert/1)

      case Enum.find(results, &match?({:error, _}, &1)) do
        nil -> {:ok, Enum.map(results, fn {:ok, split} -> split end)}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  defp insert_custom_splits(repo, expense, custom_splits) do
    total = Enum.reduce(custom_splits, 0, fn {_uid, amount}, acc -> acc + amount end)

    if total != expense.amount do
      {:error, "Custom splits must sum to the expense amount"}
    else
      results =
        Enum.map(custom_splits, fn {user_id, amount} ->
          %ExpenseSplit{}
          |> ExpenseSplit.changeset(%{
            amount: amount,
            expense_id: expense.id,
            user_id: user_id
          })
          |> repo.insert()
        end)

      case Enum.find(results, &match?({:error, _}, &1)) do
        nil -> {:ok, Enum.map(results, fn {:ok, split} -> split end)}
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  def update_expense(%Expense{} = expense, attrs, split_data) do
    old_expense = Repo.preload(expense, [:payer, expense_splits: :user])

    Multi.new()
    |> Multi.delete_all(:delete_splits, Ecto.assoc(expense, :expense_splits))
    |> Multi.update(:expense, Expense.changeset(expense, attrs))
    |> Multi.run(:splits, fn repo, %{expense: updated_expense} ->
      insert_splits(repo, updated_expense, attrs, split_data)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{expense: updated}} ->
        updated = Repo.preload(updated, [:payer, expense_splits: :user], force: true)

        splits_metadata =
          Enum.map(updated.expense_splits, fn s ->
            %{user: s.user.name, amount: s.amount}
          end)

        changes = build_changes(old_expense, updated)

        ActivityLogs.log(
          updated.group_id,
          "expense_updated",
          "Expense updated: \"#{updated.description}\" — #{ActivityLogs.format_amount(updated.amount)} (paid by #{updated.payer.name})",
          %{
            payer: updated.payer.name,
            amount: updated.amount,
            date: Date.to_iso8601(updated.date),
            split_type: attrs["split_type"] || attrs[:split_type] || "equal",
            splits: splits_metadata,
            changes: changes
          }
        )

        {:ok, updated}

      {:error, :expense, changeset, _} ->
        {:error, changeset}

      {:error, :splits, reason, _} ->
        {:error, reason}
    end
  end

  def change_expense(%Expense{} = expense, attrs \\ %{}) do
    Expense.changeset(expense, attrs)
  end

  def delete_expense(%Expense{} = expense) do
    expense = Repo.preload(expense, :payer)

    case Repo.delete(expense) do
      {:ok, deleted} ->
        ActivityLogs.log(
          deleted.group_id,
          "expense_deleted",
          "Expense deleted: \"#{deleted.description}\" (#{ActivityLogs.format_amount(deleted.amount)})",
          %{
            payer: expense.payer.name,
            amount: deleted.amount,
            date: Date.to_iso8601(deleted.date)
          }
        )

        {:ok, deleted}

      error ->
        error
    end
  end

  defp build_changes(old, new) do
    old_splits = split_summary(old.expense_splits)
    new_splits = split_summary(new.expense_splits)

    []
    |> maybe_add_change("description", old.description, new.description)
    |> maybe_add_change("amount", old.amount, new.amount)
    |> maybe_add_change("date", Date.to_iso8601(old.date), Date.to_iso8601(new.date))
    |> maybe_add_change("payer", old.payer.name, new.payer.name)
    |> maybe_add_change("split", old_splits, new_splits)
    |> Enum.reverse()
  end

  defp split_summary(expense_splits) do
    expense_splits
    |> Enum.sort_by(& &1.user.name)
    |> Enum.map(fn s -> "#{s.user.name}: #{ActivityLogs.format_amount(s.amount)}" end)
    |> Enum.join(", ")
  end

  defp maybe_add_change(acc, _field, same, same), do: acc

  defp maybe_add_change(acc, field, from, to) do
    [%{field: field, from: from, to: to} | acc]
  end
end
