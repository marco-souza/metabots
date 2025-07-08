defmodule Naive do
  @moduledoc """
  Documentation for `Naive`.

  ## Examples

    iex> symbol = "dogeusdt"
         Streamer.start_streaming(symbol)
         Naive.Trader.start_link(%{symbol: symbol, profit_interval: "-0.01"})

  """
end
