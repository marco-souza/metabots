defmodule State do
  @enforce_keys [:symbol, :profit_interval, :tick_size]

  defstruct [
    :symbol,
    :buy_order,
    :sell_order,
    :profit_interval,
    :tick_size
  ]
end

defmodule Naive.Trader do
  alias Streamer.Binance.TradeEvent
  alias Decimal, as: D

  use GenServer

  require Logger

  @binance_client Application.compile_env(:naive, :binance_client)

  def start_link(%{} = args) do
    GenServer.start_link(__MODULE__, args, name: :trader)
  end

  def init(%{symbol: symbol, profit_interval: profit_interval}) do
    symbol = String.upcase(symbol)

    Logger.info("Initializing new trader for #{symbol}")

    tick_size = fetch_tick_size(symbol)

    Logger.info("Fetched tick_size for #{symbol}@#{tick_size}, subscribing to trade events")

    Phoenix.PubSub.subscribe(Streamer.PubSub, "TRADE_EVENTS:#{symbol}")

    {:ok,
     %State{
       symbol: symbol,
       tick_size: tick_size,
       profit_interval: profit_interval
     }}
  end

  # New Trader, place a BUY order
  def handle_info(
        %TradeEvent{price: price},
        %State{symbol: symbol, buy_order: nil} = state
      ) do
    # FIXME: hardcoded until chapter 7
    quantity = 13

    Logger.info("Placing BUY order for #{symbol} @ #{price}, quantity: #{quantity}")

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_buy(symbol, quantity, price, "GTC")

    {:noreply, %{state | buy_order: order}}
  end

  # BUY is placed, Place SELL order
  def handle_info(
        %TradeEvent{
          quantity: quantity,
          price: event_price
        },
        %State{
          symbol: symbol,
          buy_order: %Binance.OrderResponse{
            price: buy_price,
            orig_qty: quantity
          },
          profit_interval: profit_interval,
          tick_size: tick_size,
          sell_order: nil
        } = state
      )
      when event_price <= buy_price do
    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

    Logger.info(
      "Buy order filled, placing SELL order for " <>
        "#{symbol} @ #{sell_price}, quantity: #{quantity}"
    )

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_sell(symbol, quantity, sell_price, "GTC")

    {:noreply, %{state | sell_order: order}}
  end

  # SELL is placed, trade finished
  def handle_info(
        %TradeEvent{
          quantity: quantity,
          price: event_price
        },
        %State{
          sell_order: %Binance.OrderResponse{
            orig_qty: quantity,
            price: sell_price
          }
        } = state
      )
      when event_price >= sell_price do
    Logger.info("Trade finished at #{sell_price}, trader will now exit")

    {
      :stop,
      :normal,
      # generate new state
      %State{
        symbol: state.symbol,
        profit_interval: state.profit_interval,
        tick_size: fetch_tick_size(state.symbol)
      }
    }
  end

  # Fallback scenario
  def handle_info(%TradeEvent{}, %State{} = state) do
    {:noreply, state}
  end

  defp calculate_sell_price(buy_price, profit_interval, tick_size) do
    # FIXME: hardcoded until chapter 7
    fee = "1.001"
    original_price = D.mult(buy_price, fee)

    net_target_price =
      D.mult(
        original_price,
        D.add("1.0", profit_interval)
      )

    gross_target_price = D.mult(net_target_price, fee)

    normalized_gross_target_price =
      D.mult(
        D.div_int(gross_target_price, tick_size),
        tick_size
      )

    D.to_string(normalized_gross_target_price, :normal)
  end

  defp fetch_tick_size(symbol) do
    @binance_client.get_exchange_info()
    |> elem(1)
    |> Map.get(:symbols)
    |> Enum.find(&(&1["symbol"] == symbol))
    |> Map.get("filters")
    |> Enum.find(&(&1["filterType"] == "PRICE_FILTER"))
    |> Map.get("tickSize")
  end
end
