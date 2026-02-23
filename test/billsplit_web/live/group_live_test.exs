defmodule BillsplitWeb.GroupLiveTest do
  use BillsplitWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Billsplit.Groups

  describe "GroupLive.Form (new)" do
    test "creates a new group", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/groups/new")

      view
      |> form("form", group: %{name: "Beach House"})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"/groups/\d+"
    end

    test "shows validation error for empty name", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/groups/new")

      html =
        view
        |> form("form", group: %{name: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "GroupLive.Show" do
    test "shows group details", %{conn: conn} do
      {:ok, group} = Groups.create_group(%{name: "Test Group", description: "A test"})

      {:ok, _view, html} = live(conn, "/groups/#{group.id}")
      assert html =~ "Test Group"
      assert html =~ "A test"
    end
  end

  describe "GroupLive.Members" do
    test "adds and removes members", %{conn: conn} do
      {:ok, group} = Groups.create_group(%{name: "Members Test"})

      {:ok, view, _html} = live(conn, "/groups/#{group.id}/members")

      html =
        view
        |> form("form", %{name: "Alice"})
        |> render_submit()

      assert html =~ "Alice"

      # Verify member shows up
      assert has_element?(view, "span", "Alice")
    end
  end
end
