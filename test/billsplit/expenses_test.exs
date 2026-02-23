defmodule Billsplit.ExpensesTest do
  use Billsplit.DataCase

  alias Billsplit.Expenses
  alias Billsplit.Accounts
  alias Billsplit.Groups

  defp setup_group(_context) do
    {:ok, group} = Groups.create_group(%{name: "Test Group"})
    {:ok, alice} = Accounts.create_user(%{name: "ExpAlice"})
    {:ok, bob} = Accounts.create_user(%{name: "ExpBob"})
    {:ok, _} = Groups.add_member(group.id, "ExpAlice")
    {:ok, _} = Groups.add_member(group.id, "ExpBob")

    %{group: group, alice: alice, bob: bob}
  end

  describe "create_expense/2 with equal split" do
    setup :setup_group

    test "creates expense with equal splits", %{group: group, alice: alice, bob: bob} do
      {:ok, expense} =
        Expenses.create_expense(
          %{
            description: "Pizza",
            amount: 2000,
            date: ~D[2024-01-15],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      assert expense.description == "Pizza"
      assert expense.amount == 2000
      assert length(expense.expense_splits) == 2

      splits = expense.expense_splits
      assert Enum.all?(splits, fn s -> s.amount == 1000 end)
    end

    test "rejects expense with no members", %{group: group, alice: alice} do
      result =
        Expenses.create_expense(
          %{
            description: "Solo",
            amount: 1000,
            date: ~D[2024-01-15],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: []}
        )

      assert {:error, "No members to split with"} = result
    end
  end

  describe "create_expense/2 with custom split" do
    setup :setup_group

    test "creates expense with custom splits", %{group: group, alice: alice, bob: bob} do
      {:ok, expense} =
        Expenses.create_expense(
          %{
            description: "Fancy dinner",
            amount: 5000,
            date: ~D[2024-01-15],
            split_type: "custom",
            group_id: group.id,
            payer_id: alice.id
          },
          %{custom_splits: [{alice.id, 3000}, {bob.id, 2000}]}
        )

      assert expense.amount == 5000
      splits = Enum.sort_by(expense.expense_splits, & &1.amount, :desc)
      assert Enum.map(splits, & &1.amount) == [3000, 2000]
    end

    test "rejects custom splits that don't sum to total", %{group: group, alice: alice, bob: bob} do
      result =
        Expenses.create_expense(
          %{
            description: "Bad split",
            amount: 5000,
            date: ~D[2024-01-15],
            split_type: "custom",
            group_id: group.id,
            payer_id: alice.id
          },
          %{custom_splits: [{alice.id, 2000}, {bob.id, 2000}]}
        )

      assert {:error, "Custom splits must sum to the expense amount"} = result
    end
  end

  describe "list_expenses/1" do
    setup :setup_group

    test "lists expenses for a group", %{group: group, alice: alice, bob: bob} do
      {:ok, _} =
        Expenses.create_expense(
          %{
            description: "Test",
            amount: 1000,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      expenses = Expenses.list_expenses(group.id)
      assert length(expenses) == 1
      assert hd(expenses).description == "Test"
    end
  end

  describe "update_expense/3 with equal split" do
    setup :setup_group

    test "updates expense and recalculates equal splits", %{group: group, alice: alice, bob: bob} do
      {:ok, expense} =
        Expenses.create_expense(
          %{
            description: "Pizza",
            amount: 2000,
            date: ~D[2024-01-15],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      {:ok, updated} =
        Expenses.update_expense(
          expense,
          %{
            description: "Sushi",
            amount: 3000,
            date: ~D[2024-01-16],
            split_type: "equal",
            group_id: group.id,
            payer_id: bob.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      assert updated.description == "Sushi"
      assert updated.amount == 3000
      assert updated.payer_id == bob.id
      assert length(updated.expense_splits) == 2
      assert Enum.all?(updated.expense_splits, fn s -> s.amount == 1500 end)
    end
  end

  describe "update_expense/3 with custom split" do
    setup :setup_group

    test "updates expense and replaces custom splits", %{group: group, alice: alice, bob: bob} do
      {:ok, expense} =
        Expenses.create_expense(
          %{
            description: "Dinner",
            amount: 5000,
            date: ~D[2024-01-15],
            split_type: "custom",
            group_id: group.id,
            payer_id: alice.id
          },
          %{custom_splits: [{alice.id, 3000}, {bob.id, 2000}]}
        )

      {:ok, updated} =
        Expenses.update_expense(
          expense,
          %{
            description: "Dinner v2",
            amount: 4000,
            date: ~D[2024-01-16],
            split_type: "custom",
            group_id: group.id,
            payer_id: alice.id
          },
          %{custom_splits: [{alice.id, 1000}, {bob.id, 3000}]}
        )

      assert updated.description == "Dinner v2"
      assert updated.amount == 4000
      splits = Enum.sort_by(updated.expense_splits, & &1.amount)
      assert Enum.map(splits, & &1.amount) == [1000, 3000]
    end

    test "rejects update when custom splits don't sum to total", %{group: group, alice: alice, bob: bob} do
      {:ok, expense} =
        Expenses.create_expense(
          %{
            description: "Dinner",
            amount: 5000,
            date: ~D[2024-01-15],
            split_type: "custom",
            group_id: group.id,
            payer_id: alice.id
          },
          %{custom_splits: [{alice.id, 3000}, {bob.id, 2000}]}
        )

      result =
        Expenses.update_expense(
          expense,
          %{
            description: "Dinner",
            amount: 5000,
            date: ~D[2024-01-15],
            split_type: "custom",
            group_id: group.id,
            payer_id: alice.id
          },
          %{custom_splits: [{alice.id, 1000}, {bob.id, 1000}]}
        )

      assert {:error, "Custom splits must sum to the expense amount"} = result
    end
  end

  describe "delete_expense/1" do
    setup :setup_group

    test "deletes expense and its splits", %{group: group, alice: alice, bob: bob} do
      {:ok, expense} =
        Expenses.create_expense(
          %{
            description: "Delete me",
            amount: 1000,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      assert {:ok, _} = Expenses.delete_expense(expense)
      assert Expenses.list_expenses(group.id) == []
    end
  end
end
