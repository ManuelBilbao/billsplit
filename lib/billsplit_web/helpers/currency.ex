defmodule BillsplitWeb.Helpers.Currency do
  @doc """
  Format cents as a dollar string. E.g., 1050 -> "$10.50"
  """
  def format_currency(cents) when is_integer(cents) do
    negative = cents < 0
    cents = abs(cents)
    dollars = div(cents, 100)
    remaining_cents = rem(cents, 100)

    formatted = "$#{dollars}.#{String.pad_leading(Integer.to_string(remaining_cents), 2, "0")}"
    if negative, do: "-#{formatted}", else: formatted
  end

  def format_currency(_), do: "$0.00"

  @doc """
  Parse a dollar string to cents. E.g., "10.50" -> 1050
  Returns {:ok, cents} or {:error, reason}
  """
  def parse_to_cents(str) when is_binary(str) do
    str = str |> String.trim() |> String.replace("$", "") |> String.replace(",", "")

    case Float.parse(str) do
      {float, ""} ->
        cents = round(float * 100)

        if cents > 0 do
          {:ok, cents}
        else
          {:error, "Amount must be positive"}
        end

      _ ->
        {:error, "Invalid amount format"}
    end
  end

  def parse_to_cents(_), do: {:error, "Invalid amount"}
end
