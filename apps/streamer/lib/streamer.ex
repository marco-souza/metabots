defmodule Streamer do
  @moduledoc """
  Documentation for `Streamer`.
  """

  @doc """
  Start streaming all trades of the passed symbol.

  ## Examples

      iex> Streamer.start_streaming("xrpusdt")
      :world

  """
  def start_streaming(symbol) do
    Streamer.Binance.start_link(symbol)
  end
end
