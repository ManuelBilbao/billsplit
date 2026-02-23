defmodule BillsplitWeb.ExpenseLive.Form do
  use BillsplitWeb, :live_view

  alias Billsplit.Groups
  alias Billsplit.Expenses
  alias BillsplitWeb.Helpers.Currency

  def mount(%{"group_id" => group_id}, _session, socket) do
    group = Groups.get_group!(group_id)
    members = Groups.list_members(group.id)

    {:ok, assign(socket, group: group, members: members)}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    all_ids = MapSet.new(socket.assigns.members, & &1.id)

    assign(socket,
      page_title: "Add Expense",
      expense: nil,
      description: "",
      amount_str: "",
      date: Date.to_iso8601(Date.utc_today()),
      split_type: "equal",
      payer_id: "",
      custom_splits: %{},
      selected_member_ids: all_ids,
      errors: %{}
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    expense = Expenses.get_expense!(id)

    split_member_ids = MapSet.new(expense.expense_splits, & &1.user_id)

    custom_splits =
      if expense.split_type == "custom" do
        Enum.reduce(expense.expense_splits, %{}, fn split, acc ->
          Map.put(acc, split.user_id, Currency.format_currency(split.amount))
        end)
      else
        %{}
      end

    assign(socket,
      page_title: "Edit Expense",
      expense: expense,
      description: expense.description,
      amount_str: Currency.format_currency(expense.amount),
      date: Date.to_iso8601(expense.date),
      split_type: expense.split_type,
      payer_id: to_string(expense.payer_id),
      custom_splits: custom_splits,
      selected_member_ids: split_member_ids,
      errors: %{}
    )
  end

  def handle_event("toggle_member", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    selected = socket.assigns.selected_member_ids

    selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply, assign(socket, :selected_member_ids, selected)}
  end

  def handle_event("validate", params, socket) do
    socket =
      socket
      |> assign(:description, params["description"] || "")
      |> assign(:amount_str, params["amount"] || "")
      |> assign(:date, params["date"] || "")
      |> assign(:payer_id, params["payer_id"] || "")
      |> assign(:split_type, params["split_type"] || "equal")

    custom_splits =
      if params["split_type"] == "custom" do
        Enum.reduce(socket.assigns.members, %{}, fn member, acc ->
          key = "split_#{member.id}"
          val = params[key] || ""
          Map.put(acc, member.id, val)
        end)
      else
        socket.assigns.custom_splits
      end

    {:noreply, assign(socket, :custom_splits, custom_splits)}
  end

  def handle_event("save", params, socket) do
    description = String.trim(params["description"] || "")
    amount_str = String.trim(params["amount"] || "")
    date_str = params["date"] || ""
    payer_id_str = params["payer_id"] || ""
    split_type = params["split_type"] || "equal"
    selected = socket.assigns.selected_member_ids

    errors = %{}

    errors = if description == "", do: Map.put(errors, :description, "is required"), else: errors
    errors = if payer_id_str == "", do: Map.put(errors, :payer_id, "is required"), else: errors

    errors =
      if MapSet.size(selected) == 0,
        do: Map.put(errors, :members, "at least one member must be selected"),
        else: errors

    {errors, amount_cents} =
      case Currency.parse_to_cents(amount_str) do
        {:ok, cents} -> {errors, cents}
        {:error, msg} -> {Map.put(errors, :amount, msg), 0}
      end

    {errors, date} =
      case Date.from_iso8601(date_str) do
        {:ok, d} -> {errors, d}
        _ -> {Map.put(errors, :date, "is invalid"), nil}
      end

    if errors != %{} do
      {:noreply, assign(socket, :errors, errors)}
    else
      payer_id = String.to_integer(payer_id_str)
      member_ids = MapSet.to_list(selected)

      split_data =
        case split_type do
          "equal" ->
            %{member_ids: member_ids}

          "custom" ->
            custom =
              socket.assigns.members
              |> Enum.filter(fn m -> MapSet.member?(selected, m.id) end)
              |> Enum.reduce([], fn member, acc ->
                key = "split_#{member.id}"
                val = params[key] || "0"

                case Currency.parse_to_cents(val) do
                  {:ok, cents} -> [{member.id, cents} | acc]
                  _ -> acc
                end
              end)

            %{custom_splits: custom}
        end

      attrs = %{
        description: description,
        amount: amount_cents,
        date: date,
        split_type: split_type,
        group_id: socket.assigns.group.id,
        payer_id: payer_id
      }

      save_expense(socket, socket.assigns.live_action, attrs, split_data)
    end
  end

  defp save_expense(socket, :new, attrs, split_data) do
    case Expenses.create_expense(attrs, split_data) do
      {:ok, _expense} ->
        {:noreply,
         socket
         |> put_flash(:info, "Expense added successfully")
         |> push_navigate(to: ~p"/groups/#{socket.assigns.group}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Enum.reduce(changeset.errors, %{}, fn {field, {msg, _}}, acc ->
            Map.put(acc, field, msg)
          end)

        {:noreply, assign(socket, :errors, errors)}

      {:error, msg} when is_binary(msg) ->
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  defp save_expense(socket, :edit, attrs, split_data) do
    case Expenses.update_expense(socket.assigns.expense, attrs, split_data) do
      {:ok, _expense} ->
        {:noreply,
         socket
         |> put_flash(:info, "Expense updated successfully")
         |> push_navigate(to: ~p"/groups/#{socket.assigns.group}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        errors =
          Enum.reduce(changeset.errors, %{}, fn {field, {msg, _}}, acc ->
            Map.put(acc, field, msg)
          end)

        {:noreply, assign(socket, :errors, errors)}

      {:error, msg} when is_binary(msg) ->
        {:noreply, put_flash(socket, :error, msg)}
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

      <h1 class="text-2xl font-bold mb-6">{@page_title}</h1>

      <div :if={@members == []} class="alert alert-warning mb-4">
        No members in this group yet.
        <.link navigate={~p"/groups/#{@group}/members"} class="link">Add members first</.link>.
      </div>

      <form :if={@members != []} phx-change="validate" phx-submit="save" class="space-y-4">
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Description</legend>
          <input
            type="text"
            name="description"
            value={@description}
            class={["input w-full", @errors[:description] && "input-error"]}
            phx-debounce="300"
          />
          <p :if={@errors[:description]} class="text-error text-sm mt-1">{@errors[:description]}</p>
        </fieldset>

        <fieldset class="fieldset">
          <legend class="fieldset-legend">Amount ($)</legend>
          <input
            type="text"
            name="amount"
            value={@amount_str}
            placeholder="0.00"
            class={["input w-full", @errors[:amount] && "input-error"]}
            phx-debounce="300"
          />
          <p :if={@errors[:amount]} class="text-error text-sm mt-1">{@errors[:amount]}</p>
        </fieldset>

        <fieldset class="fieldset">
          <legend class="fieldset-legend">Date</legend>
          <input
            type="date"
            name="date"
            value={@date}
            class={["input w-full", @errors[:date] && "input-error"]}
          />
          <p :if={@errors[:date]} class="text-error text-sm mt-1">{@errors[:date]}</p>
        </fieldset>

        <fieldset class="fieldset">
          <legend class="fieldset-legend">Paid by</legend>
          <select name="payer_id" class={["select w-full", @errors[:payer_id] && "select-error"]}>
            <option value="">Select who paid...</option>
            <option :for={member <- @members} value={member.id} selected={to_string(member.id) == @payer_id}>
              {member.name}
            </option>
          </select>
          <p :if={@errors[:payer_id]} class="text-error text-sm mt-1">{@errors[:payer_id]}</p>
        </fieldset>

        <fieldset class="fieldset">
          <legend class="fieldset-legend">Split type</legend>
          <div class="flex gap-4">
            <label class="flex items-center gap-2 cursor-pointer">
              <input type="radio" name="split_type" value="equal" checked={@split_type == "equal"} class="radio" />
              Equal
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input type="radio" name="split_type" value="custom" checked={@split_type == "custom"} class="radio" />
              Custom
            </label>
          </div>
        </fieldset>

        <fieldset class="fieldset">
          <legend class="fieldset-legend">Split between</legend>
          <div class="space-y-2">
            <label :for={member <- @members} class="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                class="checkbox"
                checked={MapSet.member?(@selected_member_ids, member.id)}
                phx-click="toggle_member"
                phx-value-id={member.id}
              />
              {member.name}
            </label>
          </div>
          <p :if={@errors[:members]} class="text-error text-sm mt-1">{@errors[:members]}</p>
        </fieldset>

        <div :if={@split_type == "custom"} class="space-y-2">
          <p class="text-sm text-base-content/60">Enter the amount each person owes:</p>
          <div
            :for={member <- Enum.filter(@members, &MapSet.member?(@selected_member_ids, &1.id))}
            class="flex items-center gap-3"
          >
            <label class="w-32 font-medium">{member.name}</label>
            <input
              type="text"
              name={"split_#{member.id}"}
              value={@custom_splits[member.id] || ""}
              placeholder="0.00"
              class="input flex-1"
              phx-debounce="300"
            />
          </div>
        </div>

        <button type="submit" class="btn btn-primary">
          {if @live_action == :new, do: "Add Expense", else: "Update Expense"}
        </button>
      </form>
    </Layouts.app>
    """
  end
end
