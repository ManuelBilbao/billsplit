defmodule BillsplitWeb.GroupLive.Members do
  use BillsplitWeb, :live_view

  alias Billsplit.Groups

  def mount(%{"id" => id}, _session, socket) do
    group = Groups.get_group!(id)
    members = Groups.list_members(group.id)

    {:ok,
     assign(socket,
       page_title: "Members - #{group.name}",
       group: group,
       members: members,
       new_member_name: ""
     )}
  end

  def handle_event("update_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :new_member_name, name)}
  end

  def handle_event("add_member", %{"name" => name}, socket) do
    name = String.trim(name)

    if name == "" do
      {:noreply, put_flash(socket, :error, "Name cannot be empty")}
    else
      case Groups.add_member(socket.assigns.group.id, name) do
        {:ok, _} ->
          members = Groups.list_members(socket.assigns.group.id)

          {:noreply,
           socket
           |> assign(members: members, new_member_name: "")
           |> put_flash(:info, "#{name} added to group")}

        {:error, %Ecto.Changeset{errors: errors}} ->
          msg =
            if Keyword.has_key?(errors, :group_id_user_id) do
              "#{name} is already in this group"
            else
              "Could not add member"
            end

          {:noreply, put_flash(socket, :error, msg)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not add member")}
      end
    end
  end

  def handle_event("remove_member", %{"user-id" => user_id}, socket) do
    case Groups.remove_member(socket.assigns.group.id, user_id) do
      {:ok, _} ->
        members = Groups.list_members(socket.assigns.group.id)
        {:noreply, assign(socket, :members, members) |> put_flash(:info, "Member removed")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove member")}
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

      <h1 class="text-2xl font-bold mb-6">Manage Members</h1>

      <form phx-submit="add_member" class="flex gap-2 mb-6">
        <input
          type="text"
          name="name"
          value={@new_member_name}
          placeholder="Enter name..."
          class="input flex-1"
          phx-change="update_name"
          phx-debounce="100"
          autocomplete="off"
        />
        <button type="submit" class="btn btn-primary">Add Member</button>
      </form>

      <div :if={@members == []} class="text-center py-8 text-base-content/60">
        No members yet. Add someone above!
      </div>

      <ul class="space-y-2">
        <li :for={member <- @members} class="flex items-center justify-between p-3 bg-base-200 rounded-lg">
          <span class="font-medium">{member.name}</span>
          <button
            phx-click="remove_member"
            phx-value-user-id={member.id}
            data-confirm={"Remove #{member.name} from group?"}
            class="btn btn-ghost btn-xs text-error"
          >
            Remove
          </button>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end
