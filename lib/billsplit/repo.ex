defmodule Billsplit.Repo do
  use Ecto.Repo,
    otp_app: :billsplit,
    adapter: Ecto.Adapters.SQLite3
end
