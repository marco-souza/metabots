defmodule Naive do
  @moduledoc """
  Documentation for `Naive`.
  """
  @doc """
  Send a trade event

  ## Examples

      iex> symbol = "dogeusdt"
           Naive.Trader.start_link(%{symbol: symbol, profit_interval: "-0.01"})
           Streamer.start_streaming(symbol)

  """
  def send_event(%Streamer.Binance.TradeEvent{} = event) do
    GenServer.cast(:trader, event)
  end
end
