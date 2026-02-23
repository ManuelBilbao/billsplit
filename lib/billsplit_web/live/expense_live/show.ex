defmodule BillsplitWeb.ExpenseLive.Show do
  use BillsplitWeb, :live_view

  import BillsplitWeb.Helpers.Currency

  alias Billsplit.Expenses

  def mount(%{"group_id" => group_id, "id" => id}, _session, socket) do
    expense = Expenses.get_expense!(id)

    {:ok,
     assign(socket,
       page_title: expense.description,
       group_id: group_id,
       expense: expense
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mb-4">
        <.link navigate={~p"/groups/#{@group_id}"} class="btn btn-ghost btn-sm">
          &larr; Back to Group
        </.link>
      </div>

      <div class="flex items-start justify-between mb-2">
        <h1 class="text-2xl font-bold">{@expense.description}</h1>
        <.link navigate={~p"/groups/#{@group_id}/expenses/#{@expense}/edit"} class="btn btn-ghost btn-sm">
          Edit
        </.link>
      </div>

      <div class="space-y-4">
        <div class="card bg-base-200">
          <div class="card-body p-4 space-y-2">
            <div class="flex justify-between">
              <span class="text-base-content/60">Amount</span>
              <span class="font-bold text-lg">{format_currency(@expense.amount)}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Paid by</span>
              <span class="font-medium">{@expense.payer.name}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Date</span>
              <span>{@expense.date}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-base-content/60">Split type</span>
              <span class="capitalize">{@expense.split_type}</span>
            </div>
          </div>
        </div>

        <h2 class="text-lg font-semibold mt-4">Split breakdown</h2>
        <div class="space-y-1">
          <div
            :for={split <- @expense.expense_splits}
            class="flex items-center justify-between p-3 bg-base-200 rounded-lg"
          >
            <span>{split.user.name}</span>
            <span class="font-semibold">{format_currency(split.amount)}</span>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
