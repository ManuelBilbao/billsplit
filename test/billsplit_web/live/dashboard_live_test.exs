defmodule BillsplitWeb.DashboardLiveTest do
  use BillsplitWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Billsplit.Groups

  test "renders empty dashboard", %{conn: conn} do
    {:ok, view, html} = live(conn, "/")
    assert html =~ "Groups"
    assert html =~ "No groups yet"
    assert has_element?(view, "a", "New Group")
  end

  test "lists groups", %{conn: conn} do
    {:ok, _group} = Groups.create_group(%{name: "Weekend Trip"})

    {:ok, _view, html} = live(conn, "/")
    assert html =~ "Weekend Trip"
  end

  test "navigates to new group form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    {:ok, _view, html} =
      view
      |> element("a", "New Group")
      |> render_click()
      |> follow_redirect(conn)

    assert html =~ "New Group"
  end
end
