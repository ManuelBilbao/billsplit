defmodule BillsplitWeb.PageController do
  use BillsplitWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
