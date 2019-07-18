defmodule Bitcoin.Monitor do
  @moduledoc false
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def init(args) do
    Process.register(self(), BitcoinSimulator.Bitcoin.Monitor)
    {bosspid, numZeros, name} = args

    state = %{
      peer_number: 0,
      blockchain_length: 1,
      mining_difficulty: numZeros,
      total_value: 20,
      new_blocks: [],
      new_txs: []
    }
    #send self(), :update
    {:ok, state}
  end

  def handle_call({:stat, type}, _from, state) do
    {result, new_state} =
      case type do
        :peer_number ->
          {state.peer_number, state}
        :blockchain_length ->
          {state.blockchain_length, state}
        :mining_difficulty ->
          {state.mining_difficulty, state}
        :total_value ->
          {state.blockchain_length * 20, state}
        :tx_frequency ->
          {length(state.new_txs), %{state | new_txs: []}}
        :mine_frequency ->
          {length(state.new_blocks), %{state | new_blocks: []}}
      end
    {:reply, result, new_state}
  end

  def handle_cast({:new_tx, transaction}, state) do
    new_state = %{state | new_txs: [transaction | state.new_txs]}
    {:noreply, new_state}
  end

  def handle_cast({:new_block, block}, state) do
    state = %{state | blockchain_length: state.blockchain_length + 1}
    new_state = %{state | new_blocks: [block | state.new_blocks]}
    {:noreply, new_state}
  end

  def handle_cast({:add_peer}, state) do
    new_state = %{state | peer_number: state.peer_number + 1}
    {:noreply, new_state}
  end


end
