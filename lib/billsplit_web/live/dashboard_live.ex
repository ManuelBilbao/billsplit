defmodule BillsplitWeb.DashboardLive do
  use BillsplitWeb, :live_view

  import BillsplitWeb.Helpers.Currency

  alias Billsplit.Groups

  def mount(_params, _session, socket) do
    groups = Groups.list_groups()

    groups_with_stats =
      Enum.map(groups, fn group ->
        {group, Groups.group_stats(group)}
      end)

    {:ok, assign(socket, page_title: "Dashboard", groups_with_stats: groups_with_stats)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">Groups</h1>
        <.link navigate={~p"/groups/new"} class="btn btn-primary">
          New Group
        </.link>
      </div>

      <div :if={@groups_with_stats == []} class="text-center py-12 text-base-content/60">
        <p class="text-lg">No groups yet.</p>
        <p class="mt-2">Create your first group to start splitting bills!</p>
      </div>

      <div class="space-y-3">
        <.link
          :for={{group, stats} <- @groups_with_stats}
          navigate={~p"/groups/#{group}"}
          class="card bg-base-200 shadow-sm hover:shadow-md transition-shadow cursor-pointer block"
        >
          <div class="card-body p-4">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="card-title text-lg">{group.name}</h2>
                <p :if={group.description} class="text-sm text-base-content/60 mt-1">
                  {group.description}
                </p>
              </div>
              <div class="text-right text-sm text-base-content/60">
                <div>{stats.member_count} members</div>
                <div>{stats.expense_count} expenses</div>
                <div class="font-semibold text-base-content">
                  {format_currency(stats.total_expenses)}
                </div>
              </div>
            </div>
          </div>
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
