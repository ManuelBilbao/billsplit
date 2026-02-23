defmodule BillsplitWeb.GroupLive.Show do
  use BillsplitWeb, :live_view

  import BillsplitWeb.Helpers.Currency

  alias Billsplit.Groups
  alias Billsplit.Expenses

  def mount(%{"id" => id}, _session, socket) do
    group = Groups.get_group!(id)
    expenses = Expenses.list_expenses(group.id)
    members = Groups.list_members(group.id)
    stats = Groups.group_stats(group)

    {:ok,
     assign(socket,
       page_title: group.name,
       group: group,
       expenses: expenses,
       members: members,
       stats: stats,
       tab: "expenses"
     )}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end

  def handle_event("delete_expense", %{"id" => id}, socket) do
    expense = Expenses.get_expense!(id)
    {:ok, _} = Expenses.delete_expense(expense)

    group = Groups.get_group!(socket.assigns.group.id)
    expenses = Expenses.list_expenses(group.id)
    stats = Groups.group_stats(group)

    {:noreply,
     socket
     |> assign(group: group, expenses: expenses, stats: stats)
     |> put_flash(:info, "Expense deleted")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mb-4">
        <.link navigate={~p"/"} class="btn btn-ghost btn-sm">&larr; All Groups</.link>
      </div>

      <div class="flex items-start justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold">{@group.name}</h1>
          <p :if={@group.description} class="text-base-content/60 mt-1">{@group.description}</p>
          <div class="flex gap-4 mt-2 text-sm text-base-content/60">
            <span>{@stats.member_count} members</span>
            <span>{@stats.expense_count} expenses</span>
            <span class="font-semibold">{format_currency(@stats.total_expenses)} total</span>
          </div>
        </div>
        <.link navigate={~p"/groups/#{@group}/edit"} class="btn btn-ghost btn-sm">Edit</.link>
      </div>

      <div class="flex gap-2 mb-6">
        <.link navigate={~p"/groups/#{@group}/members"} class="btn btn-outline btn-sm">
          Manage Members
        </.link>
        <.link navigate={~p"/groups/#{@group}/expenses/new"} class="btn btn-primary btn-sm">
          Add Expense
        </.link>
        <.link navigate={~p"/groups/#{@group}/debts"} class="btn btn-secondary btn-sm">
          View Debts
        </.link>
        <.link navigate={~p"/groups/#{@group}/activity"} class="btn btn-outline btn-sm">
          Activity Log
        </.link>
      </div>

      <div role="tablist" class="tabs tabs-border mb-4">
        <button
          role="tab"
          class={["tab", @tab == "expenses" && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="expenses"
        >
          Expenses
        </button>
        <button
          role="tab"
          class={["tab", @tab == "members" && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="members"
        >
          Members
        </button>
      </div>

      <div :if={@tab == "expenses"}>
        <div :if={@expenses == []} class="text-center py-8 text-base-content/60">
          No expenses yet. Add one to get started!
        </div>
        <div class="space-y-2">
          <div :for={expense <- @expenses} class="card bg-base-200 shadow-sm">
            <div class="card-body p-4">
              <div class="flex items-center justify-between">
                <.link navigate={~p"/groups/#{@group}/expenses/#{expense}"} class="flex-1">
                  <div class="font-semibold">{expense.description}</div>
                  <div class="text-sm text-base-content/60">
                    Paid by {expense.payer.name} &middot; {expense.date}
                  </div>
                </.link>
                <div class="flex items-center gap-3">
                  <span class="font-bold">{format_currency(expense.amount)}</span>
                  <.link navigate={~p"/groups/#{@group}/expenses/#{expense}/edit"} class="btn btn-ghost btn-xs">
                    Edit
                  </.link>
                  <button
                    phx-click="delete_expense"
                    phx-value-id={expense.id}
                    data-confirm="Delete this expense?"
                    class="btn btn-ghost btn-xs text-error"
                  >
                    Delete
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div :if={@tab == "members"}>
        <div :if={@members == []} class="text-center py-8 text-base-content/60">
          No members yet.
        </div>
        <ul class="space-y-1">
          <li :for={member <- @members} class="p-3 bg-base-200 rounded-lg">
            {member.name}
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
