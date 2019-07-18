defmodule BitcoinSimulatorWeb.MonitorCommander do
  use Drab.Commander

  alias BitcoinSimulator.Bitcoin.Monitor

  onload :start_live_update

  def start_live_update(socket) do
    spawn_link(fn -> stat_update(socket) end)
  end

  defp stat_update(socket) do
    tx_frequency = GenServer.call(Monitor, {:stat, :tx_frequency})
    mine_frequency = GenServer.call(Monitor, {:stat, :mine_frequency})
    peer_number = GenServer.call(Monitor, {:stat, :peer_number})
    blockchain_length = GenServer.call(Monitor, {:stat, :blockchain_length})
    mining_difficulty = GenServer.call(Monitor, {:stat, :mining_difficulty})
    total_value = GenServer.call(Monitor, {:stat, :total_value})

    js_script = "
      tx_chart.data.datasets.forEach((dataset) => {
        dataset.data.shift();
        dataset.data.push(#{tx_frequency * 60});
      });
      tx_chart.update();

      mine_chart.data.datasets.forEach((dataset) => {
        dataset.data.shift();
        dataset.data.push(#{mine_frequency * 60});
      });
      mine_chart.update();
    "

    Drab.Core.exec_js(socket, js_script)

    Drab.Live.poke(socket, BitcoinSimulatorWeb.MonitorView, "index.html.eex", peer_number: peer_number,
      blockchain_length: blockchain_length, mining_difficulty: mining_difficulty, total_value: total_value)

    :timer.sleep(1000)
    stat_update(socket)
  end

end
