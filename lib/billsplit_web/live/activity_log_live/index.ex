defmodule BillsplitWeb.ActivityLogLive.Index do
  use BillsplitWeb, :live_view

  alias Billsplit.Groups
  alias Billsplit.ActivityLogs

  def mount(%{"id" => id}, _session, socket) do
    group = Groups.get_group!(id)
    logs = ActivityLogs.list_logs(group.id)

    {:ok,
     assign(socket,
       page_title: "Activity - #{group.name}",
       group: group,
       logs: logs,
       expanded: MapSet.new()
     )}
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    id = String.to_integer(id)

    expanded =
      if MapSet.member?(socket.assigns.expanded, id) do
        MapSet.delete(socket.assigns.expanded, id)
      else
        MapSet.put(socket.assigns.expanded, id)
      end

    {:noreply, assign(socket, expanded: expanded)}
  end

  defp action_icon("expense_created"), do: "+"
  defp action_icon("expense_updated"), do: "~"
  defp action_icon("expense_deleted"), do: "-"
  defp action_icon("settlement_created"), do: "$"
  defp action_icon("settle_all"), do: "$"
  defp action_icon(_), do: "?"

  defp action_badge_class("expense_created"), do: "badge-success"
  defp action_badge_class("expense_updated"), do: "badge-warning"
  defp action_badge_class("expense_deleted"), do: "badge-error"
  defp action_badge_class("settlement_created"), do: "badge-info"
  defp action_badge_class("settle_all"), do: "badge-info"
  defp action_badge_class(_), do: "badge-ghost"

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %H:%M")
  end

  defp has_metadata?(log) do
    log.metadata != nil and log.metadata != %{}
  end

  defp format_change_value("amount", cents) when is_integer(cents) do
    ActivityLogs.format_amount(cents)
  end

  defp format_change_value(_field, value), do: to_string(value)

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mb-4">
        <.link navigate={~p"/groups/#{@group}"} class="btn btn-ghost btn-sm">
          &larr; Back to {@group.name}
        </.link>
      </div>

      <h1 class="text-2xl font-bold mb-6">Activity Log</h1>

      <div :if={@logs == []} class="text-center py-8 text-base-content/60">
        No activity recorded yet.
      </div>

      <div :if={@logs != []} class="space-y-2">
        <div :for={log <- @logs} class="bg-base-200 rounded-lg">
          <div
            class={[
              "flex items-start gap-3 p-3",
              has_metadata?(log) && "cursor-pointer hover:bg-base-300 rounded-lg transition-colors"
            ]}
            phx-click={has_metadata?(log) && "toggle"}
            phx-value-id={log.id}
          >
            <span class={["badge badge-sm font-mono mt-0.5", action_badge_class(log.action)]}>
              {action_icon(log.action)}
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-sm">{log.description}</p>
              <p class="text-xs text-base-content/50 mt-0.5">
                {format_timestamp(log.inserted_at)}
              </p>
            </div>
            <span :if={has_metadata?(log)} class="text-base-content/40 text-xs mt-1">
              {if MapSet.member?(@expanded, log.id), do: "▲", else: "▼"}
            </span>
          </div>

          <div
            :if={MapSet.member?(@expanded, log.id) and has_metadata?(log)}
            class="px-3 pb-3 pt-0 ml-10"
          >
            <.detail_panel log={log} />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp detail_panel(%{log: %{action: "expense_created", metadata: meta}} = assigns) do
    assigns = assign(assigns, :meta, meta)

    ~H"""
    <div class="text-sm space-y-2 bg-base-100 rounded-lg p-3">
      <div class="flex gap-4 text-base-content/70">
        <span>Paid by: <strong>{@meta["payer"]}</strong></span>
        <span>Date: {@meta["date"]}</span>
        <span>Split: {@meta["split_type"]}</span>
      </div>
      <table :if={@meta["splits"]} class="table table-xs">
        <thead>
          <tr>
            <th>Person</th>
            <th class="text-right">Owes</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={split <- @meta["splits"]}>
            <td>{split["user"]}</td>
            <td class="text-right">{ActivityLogs.format_amount(split["amount"])}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp detail_panel(%{log: %{action: "expense_updated", metadata: meta}} = assigns) do
    assigns = assign(assigns, :meta, meta)

    ~H"""
    <div class="text-sm space-y-2 bg-base-100 rounded-lg p-3">
      <div :if={@meta["changes"] != nil and @meta["changes"] != []} class="space-y-1">
        <p class="font-medium text-base-content/80">Changes:</p>
        <div :for={change <- @meta["changes"]} class="text-base-content/70">
          <span class="capitalize">{change["field"]}:</span>
          <span class="line-through text-error/70">{format_change_value(change["field"], change["from"])}</span>
          <span>&rarr;</span>
          <span class="text-success/90 font-medium">{format_change_value(change["field"], change["to"])}</span>
        </div>
      </div>
      <div class="flex gap-4 text-base-content/70">
        <span>Paid by: <strong>{@meta["payer"]}</strong></span>
        <span>Date: {@meta["date"]}</span>
        <span>Split: {@meta["split_type"]}</span>
      </div>
      <table :if={@meta["splits"]} class="table table-xs">
        <thead>
          <tr>
            <th>Person</th>
            <th class="text-right">Owes</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={split <- @meta["splits"]}>
            <td>{split["user"]}</td>
            <td class="text-right">{ActivityLogs.format_amount(split["amount"])}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp detail_panel(%{log: %{action: "expense_deleted", metadata: meta}} = assigns) do
    assigns = assign(assigns, :meta, meta)

    ~H"""
    <div class="text-sm space-y-1 bg-base-100 rounded-lg p-3 text-base-content/70">
      <div>Paid by: <strong>{@meta["payer"]}</strong></div>
      <div>Date: {@meta["date"]}</div>
      <div>Amount: {ActivityLogs.format_amount(@meta["amount"])}</div>
    </div>
    """
  end

  defp detail_panel(%{log: %{action: "settlement_created", metadata: meta}} = assigns) do
    assigns = assign(assigns, :meta, meta)

    ~H"""
    <div class="text-sm space-y-1 bg-base-100 rounded-lg p-3 text-base-content/70">
      <div>{@meta["from"]} → {@meta["to"]}</div>
      <div>Amount: {ActivityLogs.format_amount(@meta["amount"])}</div>
      <div>Date: {@meta["date"]}</div>
    </div>
    """
  end

  defp detail_panel(%{log: %{action: "settle_all", metadata: meta}} = assigns) do
    assigns = assign(assigns, :meta, meta)

    ~H"""
    <div class="text-sm bg-base-100 rounded-lg p-3">
      <table class="table table-xs">
        <thead>
          <tr>
            <th>From</th>
            <th>To</th>
            <th class="text-right">Amount</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={s <- @meta["settlements"] || []}>
            <td>{s["from"]}</td>
            <td>{s["to"]}</td>
            <td class="text-right">{ActivityLogs.format_amount(s["amount"])}</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp detail_panel(assigns) do
    ~H"""
    """
  end
end
