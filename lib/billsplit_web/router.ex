defmodule BillsplitWeb.Router do
  use BillsplitWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BillsplitWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", BillsplitWeb do
    pipe_through :browser

    live "/", DashboardLive
    live "/groups/new", GroupLive.Form, :new
    live "/groups/:id", GroupLive.Show
    live "/groups/:id/edit", GroupLive.Form, :edit
    live "/groups/:id/members", GroupLive.Members
    live "/groups/:group_id/expenses/new", ExpenseLive.Form, :new
    live "/groups/:group_id/expenses/:id", ExpenseLive.Show
    live "/groups/:group_id/expenses/:id/edit", ExpenseLive.Form, :edit
    live "/groups/:id/debts", DebtLive.Index
    live "/groups/:id/activity", ActivityLogLive.Index
  end
end
