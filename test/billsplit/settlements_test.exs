defmodule Billsplit.SettlementsTest do
  use Billsplit.DataCase

  alias Billsplit.Settlements
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

  describe "create_settlement/1" do
    test "creates a settlement with valid attrs" do
      {group, [alice, bob]} = create_group_with_members(["SetAlice", "SetBob"])

      assert {:ok, settlement} =
               Settlements.create_settlement(%{
                 amount: 1000,
                 group_id: group.id,
                 from_id: alice.id,
                 to_id: bob.id,
                 date: ~D[2024-01-15]
               })

      assert settlement.amount == 1000
      assert settlement.from_id == alice.id
      assert settlement.to_id == bob.id
      assert settlement.group_id == group.id
    end

    test "rejects settlement with amount <= 0" do
      {group, [alice, bob]} = create_group_with_members(["SetAlice2", "SetBob2"])

      assert {:error, changeset} =
               Settlements.create_settlement(%{
                 amount: 0,
                 group_id: group.id,
                 from_id: alice.id,
                 to_id: bob.id,
                 date: ~D[2024-01-15]
               })

      assert %{amount: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "rejects settlement with missing fields" do
      assert {:error, changeset} = Settlements.create_settlement(%{})

      assert %{
               amount: ["can't be blank"],
               group_id: ["can't be blank"],
               from_id: ["can't be blank"],
               to_id: ["can't be blank"],
               date: ["can't be blank"]
             } = errors_on(changeset)
    end
  end

  describe "create_settlements_from_debts/1" do
    test "settles all debts and balances go to zero" do
      {group, [alice, bob, charlie]} = create_group_with_members(["SetAll1", "SetAll2", "SetAll3"])

      # Alice pays $30 split equally
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

      # Verify debts exist before settling
      balances_before = Debts.compute_balances(group.id)
      assert balances_before[alice.id] == 2000
      assert balances_before[bob.id] == -1000
      assert balances_before[charlie.id] == -1000

      # Settle all
      assert {:ok, settlements} = Settlements.create_settlements_from_debts(group.id)
      assert length(settlements) > 0

      # Verify balances are all zero after settling
      balances_after = Debts.compute_balances(group.id)

      Enum.each(balances_after, fn {_user_id, amount} ->
        assert amount == 0
      end)
    end
  end

  describe "list_settlements/1" do
    test "lists settlements for a group" do
      {group, [alice, bob]} = create_group_with_members(["SetList1", "SetList2"])

      {:ok, _} =
        Settlements.create_settlement(%{
          amount: 500,
          group_id: group.id,
          from_id: alice.id,
          to_id: bob.id,
          date: ~D[2024-01-15]
        })

      settlements = Settlements.list_settlements(group.id)
      assert length(settlements) == 1
      assert hd(settlements).amount == 500
    end
  end

  describe "balance integration" do
    test "compute_balances reflects both expenses and settlements" do
      {group, [alice, bob]} = create_group_with_members(["SetInt1", "SetInt2"])

      # Alice pays $20 split equally -> Alice +1000, Bob -1000
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

      # Bob settles $5 (partial)
      {:ok, _} =
        Settlements.create_settlement(%{
          amount: 500,
          group_id: group.id,
          from_id: bob.id,
          to_id: alice.id,
          date: ~D[2024-01-02]
        })

      balances = Debts.compute_balances(group.id)

      # Alice: +2000 (paid) -1000 (share) -500 (received settlement) = +500
      assert balances[alice.id] == 500
      # Bob: -1000 (share) +500 (paid settlement) = -500
      assert balances[bob.id] == -500
    end

    test "simplify_debts reflects settlements" do
      {group, [alice, bob]} = create_group_with_members(["SetSimp1", "SetSimp2"])

      # Alice pays $20 split equally
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

      # Bob fully settles
      {:ok, _} =
        Settlements.create_settlement(%{
          amount: 1000,
          group_id: group.id,
          from_id: bob.id,
          to_id: alice.id,
          date: ~D[2024-01-02]
        })

      # No remaining debts
      assert Debts.simplify_debts(group.id) == []
    end
  end
end
