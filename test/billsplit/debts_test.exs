defmodule Billsplit.DebtsTest do
  use Billsplit.DataCase

  alias Billsplit.Debts
  alias Billsplit.Accounts
  alias Billsplit.Groups
  alias Billsplit.Expenses

  defp create_group_with_members(names) do
    {:ok, group} = Groups.create_group(%{name: "Test Group"})

    users =
      Enum.map(names, fn name ->
        {:ok, user} = Accounts.create_user(%{name: name})
        {:ok, _} = Groups.add_member(group.id, name)
        user
      end)

    {group, users}
  end

  describe "compute_balances/1" do
    test "returns empty map for group with no expenses" do
      {:ok, group} = Groups.create_group(%{name: "Empty"})
      assert Debts.compute_balances(group.id) == %{}
    end

    test "computes correct balances for equal split" do
      {group, [alice, bob, charlie]} = create_group_with_members(["Alice", "Bob", "Charlie"])

      # Alice pays $30, split equally among 3 ($10 each)
      {:ok, _} =
        Expenses.create_expense(
          %{
            description: "Dinner",
            amount: 3000,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id, charlie.id]}
        )

      balances = Debts.compute_balances(group.id)

      # Alice paid 3000 and owes 1000: net +2000
      assert balances[alice.id] == 2000
      # Bob paid 0 and owes 1000: net -1000
      assert balances[bob.id] == -1000
      # Charlie paid 0 and owes 1000: net -1000
      assert balances[charlie.id] == -1000
    end

    test "handles remainder pennies in equal split" do
      {group, [alice, bob, charlie]} = create_group_with_members(["Alice2", "Bob2", "Charlie2"])

      # $10 split 3 ways = 334, 333, 333
      {:ok, expense} =
        Expenses.create_expense(
          %{
            description: "Coffee",
            amount: 1000,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id, charlie.id]}
        )

      splits = expense.expense_splits |> Enum.sort_by(& &1.amount, :desc)
      amounts = Enum.map(splits, & &1.amount)

      assert Enum.sum(amounts) == 1000
      assert 334 in amounts
      assert Enum.count(amounts, &(&1 == 333)) == 2
    end
  end

  describe "simplify_debts/1" do
    test "returns empty list for group with no expenses" do
      {:ok, group} = Groups.create_group(%{name: "Empty"})
      assert Debts.simplify_debts(group.id) == []
    end

    test "simplifies two-person debt" do
      {group, [alice, bob]} = create_group_with_members(["AliceD", "BobD"])

      {:ok, _} =
        Expenses.create_expense(
          %{
            description: "Lunch",
            amount: 2000,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      settlements = Debts.simplify_debts(group.id)

      assert length(settlements) == 1
      [s] = settlements
      assert s.from_id == bob.id
      assert s.to_id == alice.id
      assert s.amount == 1000
    end

    test "simplifies three-person debts" do
      {group, [alice, bob, charlie]} = create_group_with_members(["AliceS", "BobS", "CharlieS"])

      # Alice pays $30 split equally ($10 each)
      {:ok, _} =
        Expenses.create_expense(
          %{
            description: "Dinner",
            amount: 3000,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id, charlie.id]}
        )

      settlements = Debts.simplify_debts(group.id)

      # Should produce at most 2 settlements (N-1)
      assert length(settlements) <= 2

      # Total settled should equal total debt
      total = Enum.reduce(settlements, 0, fn s, acc -> acc + s.amount end)
      assert total == 2000
    end
  end
end
