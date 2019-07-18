
defmodule BitcoinSimulator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  alias BitcoinSimulator
  alias BitcoinSimulator.Bitcoin.Monitor


  def start(_type, _args) do

    # List all child processes to be supervised
    children = [
      # Start the endpoint when the application starts
      BitcoinSimulatorWeb.Endpoint,
      # Starts a worker by calling: BitcoinSimulator.Worker.start_link(arg)
      # {BitcoinSimulator.Worker, arg},
      {DynamicSupervisor, strategy: :one_for_one, name: BitcoinSimulator.DynamicSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BitcoinSimulator.Supervisor]
    {:ok, pid}= Supervisor.start_link(children, opts)
    Bitcoin.run(100)
    {:ok, pid}
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BitcoinSimulatorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
