defmodule Billsplit.GroupsTest do
  use Billsplit.DataCase

  alias Billsplit.Groups
  alias Billsplit.Accounts

  describe "create_group/1" do
    test "creates a group with valid attrs" do
      assert {:ok, group} = Groups.create_group(%{name: "Roommates"})
      assert group.name == "Roommates"
    end

    test "fails without name" do
      assert {:error, changeset} = Groups.create_group(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_group/2" do
    test "updates group name" do
      {:ok, group} = Groups.create_group(%{name: "Old Name"})
      {:ok, updated} = Groups.update_group(group, %{name: "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "add_member/2 and list_members/1" do
    test "adds a member to a group" do
      {:ok, group} = Groups.create_group(%{name: "Test"})
      {:ok, _member} = Groups.add_member(group.id, "John")

      members = Groups.list_members(group.id)
      assert length(members) == 1
      assert hd(members).name == "John"
    end

    test "creates user if not exists" do
      {:ok, group} = Groups.create_group(%{name: "Test"})
      {:ok, _} = Groups.add_member(group.id, "NewUser")

      assert Accounts.get_user_by_name("NewUser") != nil
    end

    test "rejects duplicate member" do
      {:ok, group} = Groups.create_group(%{name: "Test"})
      {:ok, _} = Groups.add_member(group.id, "Jane")
      {:error, _} = Groups.add_member(group.id, "Jane")
    end
  end

  describe "remove_member/2" do
    test "removes a member" do
      {:ok, group} = Groups.create_group(%{name: "Test"})
      {:ok, _} = Groups.add_member(group.id, "Remove Me")

      [user] = Groups.list_members(group.id)
      {:ok, _} = Groups.remove_member(group.id, user.id)

      assert Groups.list_members(group.id) == []
    end
  end

  describe "delete_group/1" do
    test "deletes a group" do
      {:ok, group} = Groups.create_group(%{name: "Delete Me"})
      {:ok, _} = Groups.delete_group(group)

      assert_raise Ecto.NoResultsError, fn ->
        Groups.get_group!(group.id)
      end
    end
  end
end
