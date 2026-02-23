defmodule BillsplitWeb.DebtLive.Index do
  use BillsplitWeb, :live_view

  import BillsplitWeb.Helpers.Currency

  alias Billsplit.Groups
  alias Billsplit.Debts
  alias Billsplit.Accounts
  alias Billsplit.Settlements

  def mount(%{"id" => id}, _session, socket) do
    group = Groups.get_group!(id)

    members = group.members |> Enum.sort_by(& &1.name)

    socket =
      socket
      |> assign(
        page_title: "Debts - #{group.name}",
        group: group,
        members: members,
        partial_form: nil,
        show_custom_payment: false
      )
      |> refresh_data()

    {:ok, socket}
  end

  defp refresh_data(socket) do
    group = socket.assigns.group
    balances = Debts.compute_balances(group.id)
    simplified = Debts.simplify_debts(group.id)

    balance_list =
      balances
      |> Enum.map(fn {user_id, amount} ->
        user = Accounts.get_user!(user_id)
        %{user: user, amount: amount}
      end)
      |> Enum.sort_by(& &1.user.name)

    settlement_list =
      Enum.map(simplified, fn %{from_id: from_id, to_id: to_id, amount: amount} ->
        %{
          from: Accounts.get_user!(from_id),
          to: Accounts.get_user!(to_id),
          amount: amount
        }
      end)

    assign(socket,
      balance_list: balance_list,
      settlement_list: settlement_list
    )
  end

  def handle_event("settle_debt", %{"from_id" => from_id, "to_id" => to_id, "amount" => amount}, socket) do
    {from_id, _} = Integer.parse(from_id)
    {to_id, _} = Integer.parse(to_id)
    {amount, _} = Integer.parse(amount)

    case Settlements.create_settlement(%{
           amount: amount,
           group_id: socket.assigns.group.id,
           from_id: from_id,
           to_id: to_id,
           date: Date.utc_today()
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Debt settled!")
         |> assign(partial_form: nil)
         |> refresh_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to settle debt.")}
    end
  end

  def handle_event("show_partial_form", %{"from_id" => from_id, "to_id" => to_id, "amount" => amount}, socket) do
    {from_id, _} = Integer.parse(from_id)
    {to_id, _} = Integer.parse(to_id)
    {amount, _} = Integer.parse(amount)

    {:noreply, assign(socket, partial_form: %{from_id: from_id, to_id: to_id, max_amount: amount})}
  end

  def handle_event("cancel_partial", _params, socket) do
    {:noreply, assign(socket, partial_form: nil)}
  end

  def handle_event("settle_partial", %{"amount" => amount_str} = params, socket) do
    from_id = params["from_id"]
    to_id = params["to_id"]
    {from_id, _} = Integer.parse(from_id)
    {to_id, _} = Integer.parse(to_id)

    case parse_currency_input(amount_str) do
      {:ok, amount_cents} when amount_cents > 0 ->
        case Settlements.create_settlement(%{
               amount: amount_cents,
               group_id: socket.assigns.group.id,
               from_id: from_id,
               to_id: to_id,
               date: Date.utc_today()
             }) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Partial settlement recorded!")
             |> assign(partial_form: nil)
             |> refresh_data()}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to record settlement.")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Please enter a valid amount greater than 0.")}
    end
  end

  def handle_event("show_custom_payment", _params, socket) do
    {:noreply, assign(socket, show_custom_payment: true)}
  end

  def handle_event("cancel_custom_payment", _params, socket) do
    {:noreply, assign(socket, show_custom_payment: false)}
  end

  def handle_event("create_custom_payment", params, socket) do
    %{"from_id" => from_id, "to_id" => to_id, "amount" => amount_str} = params
    {from_id, _} = Integer.parse(from_id)
    {to_id, _} = Integer.parse(to_id)

    cond do
      from_id == to_id ->
        {:noreply, put_flash(socket, :error, "Payer and recipient must be different.")}

      true ->
        case parse_currency_input(amount_str) do
          {:ok, amount_cents} when amount_cents > 0 ->
            case Settlements.create_settlement(%{
                   amount: amount_cents,
                   group_id: socket.assigns.group.id,
                   from_id: from_id,
                   to_id: to_id,
                   date: Date.utc_today()
                 }) do
              {:ok, _} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Payment recorded!")
                 |> assign(show_custom_payment: false)
                 |> refresh_data()}

              {:error, _} ->
                {:noreply, put_flash(socket, :error, "Failed to record payment.")}
            end

          _ ->
            {:noreply, put_flash(socket, :error, "Please enter a valid amount greater than 0.")}
        end
    end
  end

  def handle_event("settle_all", _params, socket) do
    case Settlements.create_settlements_from_debts(socket.assigns.group.id) do
      {:ok, []} ->
        {:noreply, put_flash(socket, :info, "No debts to settle.")}

      {:ok, _settlements} ->
        {:noreply,
         socket
         |> put_flash(:info, "All debts settled!")
         |> assign(partial_form: nil)
         |> refresh_data()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to settle all debts.")}
    end
  end

  defp parse_currency_input(str) do
    str = String.trim(str)

    case Float.parse(str) do
      {float_val, _} when float_val > 0 ->
        {:ok, round(float_val * 100)}

      _ ->
        :error
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mb-4">
        <.link navigate={~p"/groups/#{@group}"} class="btn btn-ghost btn-sm">
          &larr; Back to {@group.name}
        </.link>
      </div>

      <h1 class="text-2xl font-bold mb-6">Debts &amp; Settlements</h1>

      <div :if={@balance_list == []} class="text-center py-8 text-base-content/60">
        No expenses recorded yet. Add expenses to see balances.
      </div>

      <div :if={@balance_list != []} class="space-y-6">
        <section>
          <h2 class="text-lg font-semibold mb-3">Net Balances</h2>
          <div class="space-y-2">
            <div
              :for={b <- @balance_list}
              class="flex items-center justify-between p-3 bg-base-200 rounded-lg"
            >
              <span class="font-medium">{b.user.name}</span>
              <span class={[
                "font-bold",
                b.amount > 0 && "text-success",
                b.amount < 0 && "text-error",
                b.amount == 0 && "text-base-content/60"
              ]}>
                {if b.amount >= 0, do: "+", else: ""}{format_currency(b.amount)}
              </span>
            </div>
          </div>
          <p class="text-xs text-base-content/50 mt-2">
            Positive = is owed money. Negative = owes money.
          </p>
        </section>

        <section :if={@settlement_list != []}>
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-lg font-semibold">Simplified Settlements</h2>
            <button phx-click="settle_all" class="btn btn-primary btn-sm">
              Settle All
            </button>
          </div>
          <div class="space-y-2">
            <div :for={s <- @settlement_list} class="p-3 bg-base-200 rounded-lg">
              <div class="flex items-center justify-between">
                <div>
                  <span class="font-medium text-error">{s.from.name}</span>
                  <span class="text-base-content/60 mx-2">pays</span>
                  <span class="font-medium text-success">{s.to.name}</span>
                </div>
                <div class="flex items-center gap-2">
                  <span class="font-bold">{format_currency(s.amount)}</span>
                  <button
                    phx-click="settle_debt"
                    phx-value-from_id={s.from.id}
                    phx-value-to_id={s.to.id}
                    phx-value-amount={s.amount}
                    class="btn btn-success btn-xs"
                  >
                    Settle
                  </button>
                  <button
                    phx-click="show_partial_form"
                    phx-value-from_id={s.from.id}
                    phx-value-to_id={s.to.id}
                    phx-value-amount={s.amount}
                    class="btn btn-outline btn-xs"
                  >
                    Partial
                  </button>
                </div>
              </div>
              <div
                :if={@partial_form && @partial_form.from_id == s.from.id && @partial_form.to_id == s.to.id}
                class="mt-3 flex items-center gap-2"
              >
                <form phx-submit="settle_partial" class="flex items-center gap-2 w-full">
                  <input type="hidden" name="from_id" value={s.from.id} />
                  <input type="hidden" name="to_id" value={s.to.id} />
                  <input
                    type="number"
                    name="amount"
                    step="0.01"
                    min="0.01"
                    max={s.amount / 100}
                    placeholder="Amount"
                    class="input input-bordered input-sm w-32"
                    autofocus
                  />
                  <button type="submit" class="btn btn-success btn-sm">Submit</button>
                  <button type="button" phx-click="cancel_partial" class="btn btn-ghost btn-sm">
                    Cancel
                  </button>
                </form>
              </div>
            </div>
          </div>
        </section>

        <div :if={@settlement_list == []} class="text-center py-4 text-success font-medium">
          All settled up! No payments needed.
        </div>

        <section>
          <div class="flex items-center justify-between mb-3">
            <h2 class="text-lg font-semibold">Record a Payment</h2>
          </div>
          <div :if={!@show_custom_payment}>
            <button phx-click="show_custom_payment" class="btn btn-outline btn-sm">
              Record a payment between any members
            </button>
          </div>
          <div :if={@show_custom_payment} class="p-4 bg-base-200 rounded-lg">
            <form phx-submit="create_custom_payment" class="space-y-3">
              <div class="flex items-center gap-2 flex-wrap">
                <select name="from_id" class="select select-bordered select-sm" required>
                  <option value="" disabled selected>Who paid?</option>
                  <option :for={m <- @members} value={m.id}>{m.name}</option>
                </select>
                <span class="text-base-content/60">pays</span>
                <select name="to_id" class="select select-bordered select-sm" required>
                  <option value="" disabled selected>Who received?</option>
                  <option :for={m <- @members} value={m.id}>{m.name}</option>
                </select>
              </div>
              <div class="flex items-center gap-2">
                <input
                  type="number"
                  name="amount"
                  step="0.01"
                  min="0.01"
                  placeholder="Amount"
                  class="input input-bordered input-sm w-32"
                  required
                />
                <button type="submit" class="btn btn-success btn-sm">Record</button>
                <button type="button" phx-click="cancel_custom_payment" class="btn btn-ghost btn-sm">
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
