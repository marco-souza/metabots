defmodule BinanceMock do
  use GenServer

  alias Binance.OrderBook
  alias Streamer.Binance.TradeEvent
  alias Decimal, as: D

  require Logger

  defmodule State do
    defstruct order_books: %{}, subscriptions: [], fake_order_id: 1
  end

  defmodule OrderBook do
    defstruct buy_side: [], sell_side: [], historical: []
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    {:ok, %State{}}
  end

  def handle_call(
        :generate_id,
        _from,
        %State{fake_order_id: id} = state
      ) do
    {:reply, id + 1, %{state | fake_order_id: id + 1}}
  end

  def handle_call(
        {:get_order, symbol, time, order_id},
        _from,
        %State{order_books: order_books} = state
      ) do
    order_book =
      Map.get(
        order_books,
        :"#{symbol}",
        %OrderBook{}
      )

    orders =
      order_book.buy_side ++
        order_book.sell_side ++
        order_book.historical

    result =
      orders
      |> Enum.find(
        &(&1.symbol == symbol and
            &1.time == time and
            &1.order_id == order_id)
      )

    {:reply, {:ok, result}, state}
  end

  def handle_cast(
        {:add_order, %Binance.Order{symbol: symbol} = order},
        %State{
          order_books: order_books,
          subscriptions: subscriptions
        } = state
      ) do
    new_subscriptions = subscribe_to_topic(symbol, subscriptions)
    updated_order_books = add_order(order, order_books)

    {:noreply,
     %State{
       state
       | order_books: updated_order_books,
         subscriptions: new_subscriptions
     }}
  end

  def handle_info(
        %TradeEvent{} = trade_event,
        %{order_books: order_books} = state
      ) do
    order_book =
      Map.get(
        order_books,
        :"#{trade_event.symbol}",
        %OrderBook{}
      )

    filled_buy_orders =
      order_book.buy_side
      |> Enum.take_while(&D.lt?(trade_event.price, &1.price))
      |> Enum.map(&Map.replace(&1, :status, "FILLED"))

    filled_sell_orders =
      order_book.buy_side
      |> Enum.take_while(&D.gt?(trade_event.price, &1.price))
      |> Enum.map(&Map.replace(&1, :status, "FILLED"))

    (filled_buy_orders ++ filled_sell_orders)
    |> Enum.map(&convert_order_to_event(&1, trade_event.event_time))
    |> Enum.each(&broadcast_trade_event/1)

    remaining_buy_orders =
      order_book.buy_side
      |> Enum.drop(length(filled_buy_orders))

    remaining_sell_orders =
      order_book.sell_side
      |> Enum.drop(length(filled_sell_orders))

    order_books =
      Map.replace(
        order_books,
        "#{trade_event.symbol}",
        %{
          buy_side: remaining_buy_orders,
          sell_side: remaining_sell_orders,
          historical:
            filled_buy_orders ++
              filled_sell_orders ++
              order_book.historical
        }
      )

    {:noreply, %{state | order_books: order_books}}
  end

  def get_order(symbol, time, order_id) do
    GenServer.call(__MODULE__, {:get_order, symbol, time, order_id})
  end

  def get_exchange_info() do
    Binance.get_exchange_info()
  end

  def order_limit_buy(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "BUY")
  end

  def order_limit_sell(symbol, quantity, price, "GTC") do
    order_limit(symbol, quantity, price, "SELL")
  end

  def print_order_book() do
    GenServer.call(__MODULE__, :print_order_book)
  end

  defp convert_order_to_event(%Binance.Order{} = order, time) do
    %TradeEvent{
      price: order.price,
      symbol: order.symbol,
      event_time: time - 1,
      event_type: order.type,
      quantity: order.orig_qty,
      buyer_order_id: order.order_id,
      seller_order_id: order.order_id,
      trade_id: Integer.floor_div(time, 1000),
      trade_time: time - 1,
      buyer_market_maker: false
    }
  end

  defp broadcast_trade_event(%Streamer.Binance.TradeEvent{} = trade_event) do
    Phoenix.PubSub.broadcast(
      Streamer.PubSub,
      "TRADE_EVENTS:#{trade_event.symbol}",
      trade_event
    )
  end

  defp order_limit(symbol, quantity, price, side) do
    %Binance.Order{} =
      fake_order =
      generate_fake_order(
        symbol,
        quantity,
        price,
        side
      )

    GenServer.cast(
      __MODULE__,
      {:add_order, fake_order}
    )

    # broadcast trade related to order
    broadcast_trade_event(convert_order_to_event(fake_order, fake_order.time))

    {:ok, convert_order_to_order_response(fake_order)}
  end

  defp subscribe_to_topic(symbol, subscriptions) do
    symbol = String.upcase(symbol)
    stream_name = "TRADE_EVENTS:#{symbol}"

    case Enum.member?(subscriptions, symbol) do
      false ->
        Logger.debug("BinanceMock subscribing to #{stream_name}")

        Phoenix.PubSub.subscribe(
          Streamer.PubSub,
          stream_name
        )

        [symbol | subscriptions]

      _ ->
        subscriptions
    end
  end

  defp add_order(
         %Binance.Order{symbol: symbol} = order,
         order_books
       ) do
    order_book =
      Map.get(
        order_books,
        :"#{symbol}",
        %OrderBook{}
      )

    order_book =
      if order.side == "SELL" do
        Map.replace!(
          order_book,
          :sell_side,
          [order | order_book.sell_side]
          |> Enum.sort(
            &D.lt?(
              &1.price,
              &2.price
            )
          )
        )
      else
        Map.replace!(
          order_book,
          :buy_side,
          [order | order_book.buy_side]
          |> Enum.sort(
            &D.gt?(
              &1.price,
              &2.price
            )
          )
        )
      end

    Map.put(order_books, :"#{symbol}", order_book)
  end

  defp convert_order_to_order_response(%Binance.Order{} = order) do
    %{
      struct(
        Binance.OrderResponse,
        order |> Map.to_list()
      )
      | transact_time: order.time
    }
  end

  defp generate_fake_order(symbol, quantity, price, side)
       when is_bitstring(symbol) and
              is_number(quantity) and
              is_bitstring(price) and
              (side == "BUY" or side == "SELL") do
    current_timestamp = :os.system_time(:millisecond)
    order_id = GenServer.call(__MODULE__, :generate_id)

    client_order_id =
      :crypto.hash(:md5, "#{order_id}")
      |> Base.encode16()

    Binance.Order.new(%{
      symbol: String.upcase(symbol),
      order_id: order_id,
      client_order_id: client_order_id,
      price: price,
      orig_qty: quantity,
      side: side,
      type: "LIMIT",
      status: "NEW",
      time_in_force: "GTC",
      executed_qty: "0.00000000",
      cummulative_quote_qty: "0.00000000",
      stop_price: "0.00000000",
      iceberg_qty: "0.00000000",
      time: current_timestamp,
      update_time: current_timestamp,
      is_working: true
    })
  end
end
