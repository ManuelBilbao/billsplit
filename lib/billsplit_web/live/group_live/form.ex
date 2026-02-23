defmodule BillsplitWeb.GroupLive.Form do
  use BillsplitWeb, :live_view

  alias Billsplit.Groups
  alias Billsplit.Groups.Group

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    group = %Group{}
    changeset = Groups.change_group(group)

    socket
    |> assign(page_title: "New Group", group: group)
    |> assign_form(changeset)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    group = Groups.get_group!(id)
    changeset = Groups.change_group(group)

    socket
    |> assign(page_title: "Edit Group", group: group)
    |> assign_form(changeset)
  end

  def handle_event("validate", %{"group" => group_params}, socket) do
    changeset =
      socket.assigns.group
      |> Groups.change_group(group_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"group" => group_params}, socket) do
    save_group(socket, socket.assigns.live_action, group_params)
  end

  defp save_group(socket, :new, group_params) do
    case Groups.create_group(group_params) do
      {:ok, group} ->
        {:noreply,
         socket
         |> put_flash(:info, "Group created successfully")
         |> push_navigate(to: ~p"/groups/#{group}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_group(socket, :edit, group_params) do
    case Groups.update_group(socket.assigns.group, group_params) do
      {:ok, group} ->
        {:noreply,
         socket
         |> put_flash(:info, "Group updated successfully")
         |> push_navigate(to: ~p"/groups/#{group}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mb-6">
        <.link navigate={if @live_action == :edit, do: ~p"/groups/#{@group}", else: ~p"/"} class="btn btn-ghost btn-sm">
          &larr; Back
        </.link>
      </div>

      <h1 class="text-2xl font-bold mb-6">{@page_title}</h1>

      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
        <.input field={@form[:name]} label="Name" phx-debounce="300" />
        <.input field={@form[:description]} type="textarea" label="Description (optional)" phx-debounce="300" />

        <div class="flex gap-2">
          <button type="submit" class="btn btn-primary">
            {if @live_action == :new, do: "Create Group", else: "Update Group"}
          </button>
        </div>
      </.form>
    </Layouts.app>
    """
  end
end
