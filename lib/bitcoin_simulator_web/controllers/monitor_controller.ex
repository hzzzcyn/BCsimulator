defmodule BitcoinSimulatorWeb.MonitorController do
  use BitcoinSimulatorWeb, :controller
  use Drab.Controller

  alias BitcoinSimulator.Bitcoin.Monitor

  def index(conn, _params) do
    conn
    |> assign(:peer_number, GenServer.call(Monitor, {:stat, :peer_number}))
    |> assign(:blockchain_length, GenServer.call(Monitor, {:stat, :blockchain_length}))
    |> assign(:mining_difficulty, GenServer.call(Monitor, {:stat, :mining_difficulty}))
    |> assign(:total_value, GenServer.call(Monitor, {:stat, :total_value}))
    |> render("index.html")
  end

end
