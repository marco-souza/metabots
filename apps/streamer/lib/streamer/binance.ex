defmodule Streamer.Binance do
  require Logger

  use WebSockex

  @stream_endpoint "wss://stream.binance.com:9443/ws/"

  def start_link(symbol) do
    symbol = String.downcase(symbol)

    Logger.debug("#{@stream_endpoint}#{symbol}@trade")

    WebSockex.start_link(
      "#{@stream_endpoint}#{symbol}@trade",
      __MODULE__,
      nil
    )
  end

  def handle_frame({type, msg}, state) do
    case(Jason.decode(msg)) do
      {:ok, event} -> process_event(event)
      {:error, err} -> Logger.error("Unable to parse msg: #{inspect(type)} - #{inspect(err)}")
    end

    {:ok, state}
  end

  defp process_event(%{"e" => "trade"} = event) do
    trade_event = %Streamer.Binance.TradeEvent{
      event_type: event["e"],
      event_time: event["E"],
      symbol: event["s"],
      trade_id: event["t"],
      price: event["p"],
      quantity: event["q"],
      trade_time: event["T"],
      buyer_market_maker: event["m"]
      # FIXME: fields not available (binance update)
      # buyer_order_id: event["b"],
      # seller_order_id: event["a"],
    }

    Logger.debug(
      "Trade event received! " <>
        "#{trade_event.symbol}@#{trade_event.price}"
    )

    # publish event to trade events topic
    Phoenix.PubSub.broadcast(
      Streamer.PubSub,
      "TRADE_EVENTS:#{trade_event.symbol}",
      trade_event
    )
  end
end
