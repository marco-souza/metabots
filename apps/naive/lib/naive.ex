defmodule Naive do
  @moduledoc """
  Documentation for `Naive`.
  """
  alias Streamer.Binance.TradeEvent

  @doc """
  Send a trade event

  ## Examples

      iex> Naive.send_event(event)

  """
  def send_event(%TradeEvent{} = event) do
    GenServer.cast(:trader, event)
  end
end
