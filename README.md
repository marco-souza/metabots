# Metabots

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/your-repo/ci.yml?branch=main)
![GitHub License](https://img.shields.io/github/license/your-repo/metabots)

Metabots is an Elixir umbrella project aiming to provide a robust framework for building modular bots. The primary focus of this project is to create advanced crypto trading bots, leveraging the modularity and scalability of Elixir. This project is currently under development, and additional details will be included in future updates.

## Project Structure

- **mix.exs**: Contains project configuration and dependencies.
- **mix.lock**: Ensures consistent builds by locking dependencies.

## Getting Started

To get started, clone the repository and install dependencies using:

```
mix deps.get
```

```elixir

# INFO: to test
Streamer.start_streaming("xrpusdt")
Naive.Trader.start_link(%{symbol: "XRPUSDT", profit_interval: "-0.001"})

```

For more details, refer to the official [Elixir documentation](https://elixir-lang.org/).

## License

This project is licensed under the MIT License.

