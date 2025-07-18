# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :naive,
  binance_client: BinanceMock

config :binance,
  api_key: System.get_env("BINANCE_API_KEY", ""),
  secret_key: System.get_env("BINANCE_SECRET_KEY", "")

config :logger,
  level: :info,
  format: "$data $time [$level] $metadata$message\n"
