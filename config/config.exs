# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :bitcoin_simulator, BitcoinSimulatorWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "sg7cL5rMPqmCJsUdI9sX5WkeP838Sdel0itdTY10cyuVCcbk+DOmU6X8L4meOgjK",
  render_errors: [view: BitcoinSimulatorWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BitcoinSimulator.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Drab
config :drab, BitcoinSimulatorWeb.Endpoint,
  otp_app: :bitcoin_simulator

# Configures default Drab file extension
config :phoenix, :template_engines,
  drab: Drab.Live.Engine

# Configures Drab for webpack
config :drab, BitcoinSimulatorWeb.Endpoint,
  js_socket_constructor: "window.__socket"

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
