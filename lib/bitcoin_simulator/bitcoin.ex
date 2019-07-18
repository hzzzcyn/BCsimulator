defmodule Bitcoin do
  @moduledoc """
  Documentation for Bitcoin.
  """
  alias Bitcoin.Miner, as: Miner
  alias Bitcoin.Monitor

  def main(args) do
    [numPeers] = parse_args(args)
    if numPeers <= 1 do
      IO.puts("Argument Error: Type in a number greater than 1")
      exit(self())
    end
    IO.puts "Bitcoin simulation starts with #{numPeers} peers"
    run(numPeers)
  end

  defp parse_args(args) do
    [numPeers] = args
    {numPeers, _} = Integer.parse(numPeers)
    [numPeers]
  end

  defp create_peers(peers, first_peer_pid, numZeros, peer_seq) when peer_seq <= 0 do
    peers
  end

  defp create_peers(peers, first_peer_pid, numZeros, peer_seq) when peer_seq > 0 do
    Process.sleep(100)
    peername = "Peer#{peer_seq}"
    {:ok, pid} = Miner.start_link({self(), numZeros, peername})
    GenServer.cast(BitcoinSimulator.Bitcoin.Monitor, {:add_peer})
    Miner.join(pid, first_peer_pid) # join network
    peers = Map.put(peers, peername, pid)
    create_peers(peers, first_peer_pid, numZeros, peer_seq - 1)
  end

  def run(numPeers) do
    IO.puts("Creating peers...")
    numZeros = 8
    {:ok, monitor_pid} = Monitor.start_link({self(), numZeros, "Monitor"})
    {:ok, first_peer_pid} = Miner.start_link({self(), numZeros, "Peer1"})
    peers = create_peers(%{}, first_peer_pid, numZeros, numPeers)

    Process.sleep(200)
    IO.puts "Finished creating peers, simulation starts."
    # start initial transaction
    random_transactions(peers)
  end

  def random_transactions(peers) do
    Enum.each(1..400, fn i ->
      {peername, peerpid} = Enum.random(peers)
      Miner.make_random_tx(peerpid)
      Process.sleep(200)
    end)
    Process.sleep(2000)
    random_transactions(peers)
  end

end
