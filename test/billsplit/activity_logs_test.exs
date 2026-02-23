defmodule Billsplit.ActivityLogsTest do
  use Billsplit.DataCase

  alias Billsplit.ActivityLogs
  alias Billsplit.Accounts
  alias Billsplit.Groups
  alias Billsplit.Expenses
  alias Billsplit.Settlements

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

  describe "log/3" do
    test "creates an activity log entry" do
      {:ok, group} = Groups.create_group(%{name: "Log Group"})

      assert {:ok, log} = ActivityLogs.log(group.id, "test_action", "Test description")
      assert log.action == "test_action"
      assert log.description == "Test description"
      assert log.group_id == group.id
      assert log.metadata == %{}
    end

    test "creates an activity log entry with metadata" do
      {:ok, group} = Groups.create_group(%{name: "Log Group Meta"})

      metadata = %{payer: "Alice", amount: 1000}

      assert {:ok, log} =
               ActivityLogs.log(group.id, "test_action", "Test description", metadata)

      assert log.metadata[:payer] == "Alice"
      assert log.metadata[:amount] == 1000
    end
  end

  describe "list_logs/1" do
    test "returns logs for a group in reverse chronological order" do
      {:ok, group} = Groups.create_group(%{name: "Log Group 2"})

      {:ok, _} = ActivityLogs.log(group.id, "first", "First entry")
      {:ok, _} = ActivityLogs.log(group.id, "second", "Second entry")

      logs = ActivityLogs.list_logs(group.id)
      assert length(logs) == 2
      assert hd(logs).description == "Second entry"
    end

    test "does not return logs from other groups" do
      {:ok, group1} = Groups.create_group(%{name: "Group A"})
      {:ok, group2} = Groups.create_group(%{name: "Group B"})

      {:ok, _} = ActivityLogs.log(group1.id, "action", "Group A log")
      {:ok, _} = ActivityLogs.log(group2.id, "action", "Group B log")

      logs = ActivityLogs.list_logs(group1.id)
      assert length(logs) == 1
      assert hd(logs).description == "Group A log"
    end
  end

  describe "expense logging integration" do
    test "logs expense creation with neutral description and metadata" do
      {group, [alice, bob]} = create_group_with_members(["LogAlice", "LogBob"])

      {:ok, _} =
        Expenses.create_expense(
          %{
            description: "Pizza",
            amount: 2000,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      logs = ActivityLogs.list_logs(group.id)
      assert length(logs) == 1
      log = hd(logs)
      assert log.action == "expense_created"
      assert log.description =~ "Expense added:"
      assert log.description =~ "Pizza"
      assert log.description =~ "$20.00"
      assert log.description =~ "paid by LogAlice"

      assert log.metadata["payer"] == "LogAlice"
      assert log.metadata["amount"] == 2000
      assert log.metadata["date"] == "2024-01-01"
      assert log.metadata["split_type"] == "equal"
      assert length(log.metadata["splits"]) == 2
    end

    test "logs expense update with neutral description and metadata" do
      {group, [alice, bob]} = create_group_with_members(["LogAlice2", "LogBob2"])

      {:ok, expense} =
        Expenses.create_expense(
          %{
            description: "Pizza",
            amount: 2000,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      {:ok, _} =
        Expenses.update_expense(
          expense,
          %{
            description: "Sushi",
            amount: 3000,
            date: ~D[2024-01-02],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      logs = ActivityLogs.list_logs(group.id)
      assert length(logs) == 2
      update_log = hd(logs)
      assert update_log.action == "expense_updated"
      assert update_log.description =~ "Expense updated:"
      assert update_log.description =~ "Sushi"
      assert update_log.description =~ "$30.00"
      assert update_log.description =~ "paid by LogAlice2"

      assert update_log.metadata["payer"] == "LogAlice2"
      assert update_log.metadata["amount"] == 3000
      assert update_log.metadata["splits"] != nil

      changes = update_log.metadata["changes"]
      assert is_list(changes)
      assert Enum.any?(changes, fn c -> c["field"] == "description" and c["from"] == "Pizza" and c["to"] == "Sushi" end)
      assert Enum.any?(changes, fn c -> c["field"] == "amount" and c["from"] == 2000 and c["to"] == 3000 end)
      assert Enum.any?(changes, fn c -> c["field"] == "date" end)
    end

    test "logs expense deletion with neutral description and metadata" do
      {group, [alice, bob]} = create_group_with_members(["LogAlice3", "LogBob3"])

      {:ok, expense} =
        Expenses.create_expense(
          %{
            description: "Delete me",
            amount: 1500,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      {:ok, _} = Expenses.delete_expense(expense)

      logs = ActivityLogs.list_logs(group.id)
      delete_log = hd(logs)
      assert delete_log.action == "expense_deleted"
      assert delete_log.description =~ "Expense deleted:"
      assert delete_log.description =~ "Delete me"
      assert delete_log.description =~ "$15.00"
      refute delete_log.description =~ "LogAlice3 deleted"

      assert delete_log.metadata["payer"] == "LogAlice3"
      assert delete_log.metadata["amount"] == 1500
      assert delete_log.metadata["date"] == "2024-01-01"
    end
  end

  describe "settlement logging integration" do
    test "logs settlement creation with neutral description and metadata" do
      {group, [alice, bob]} = create_group_with_members(["LogSet1", "LogSet2"])

      {:ok, _} =
        Settlements.create_settlement(%{
          amount: 1000,
          group_id: group.id,
          from_id: bob.id,
          to_id: alice.id,
          date: ~D[2024-01-15]
        })

      logs = ActivityLogs.list_logs(group.id)
      assert length(logs) == 1
      log = hd(logs)
      assert log.action == "settlement_created"
      assert log.description =~ "Payment recorded:"
      assert log.description =~ "LogSet2"
      assert log.description =~ "LogSet1"
      assert log.description =~ "$10.00"

      assert log.metadata["from"] == "LogSet2"
      assert log.metadata["to"] == "LogSet1"
      assert log.metadata["amount"] == 1000
      assert log.metadata["date"] == "2024-01-15"
    end

    test "logs settle all with metadata" do
      {group, [alice, bob]} = create_group_with_members(["LogAll1", "LogAll2"])

      {:ok, _} =
        Expenses.create_expense(
          %{
            description: "Dinner",
            amount: 2000,
            date: ~D[2024-01-01],
            split_type: "equal",
            group_id: group.id,
            payer_id: alice.id
          },
          %{member_ids: [alice.id, bob.id]}
        )

      {:ok, _} = Settlements.create_settlements_from_debts(group.id)

      logs = ActivityLogs.list_logs(group.id)
      settle_all_log = hd(logs)
      assert settle_all_log.action == "settle_all"
      assert settle_all_log.description =~ "Settled all debts"
      assert settle_all_log.description =~ "1 payment"

      assert length(settle_all_log.metadata["settlements"]) == 1
      settlement = hd(settle_all_log.metadata["settlements"])
      assert settlement["from"] == "LogAll2"
      assert settlement["to"] == "LogAll1"
      assert settlement["amount"] == 1000
    end
  end

  describe "format_amount/1" do
    test "formats cents as dollar string" do
      assert ActivityLogs.format_amount(1050) == "$10.50"
      assert ActivityLogs.format_amount(100) == "$1.00"
      assert ActivityLogs.format_amount(0) == "$0.00"
      assert ActivityLogs.format_amount(999) == "$9.99"
    end
  end
end
