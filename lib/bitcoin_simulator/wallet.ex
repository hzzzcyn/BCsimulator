defmodule Bitcoin.Wallet do
  @moduledoc false

  alias Bitcoin.Transaction, as: Transaction
  alias Bitcoin.Monitor
  use GenServer

  defmodule Walletstate do
    defstruct [:minerpid, :miner, :walletcode, :balance, :recipients, :peers]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def add_money(walletpid, amount) do
    GenServer.cast(walletpid, {:income_money, amount})
  end

  def add_recipient(pid, new_recipient) do
    GenServer.cast(pid, {:add_recipient, new_recipient})
  end

  def add_peer(pid, new_peer) do
    GenServer.cast(pid, {:add_peer, new_peer} )
  end

  def make_random_tx(walletpid) do
    GenServer.cast(walletpid, :make_random_tx)
  end

  def make_targeted_tx(pid, receivername, amount) do
    GenServer.cast(pid, {:make_targeted_tx, receivername, amount})
  end

  def check_balance(pid) do
    GenServer.call(pid, :check_balance)
  end

  def init(args) do
    {miner, minerpid, walletcode, peers} = args
    walletstate = %Walletstate{minerpid: minerpid,
      miner: miner,
      walletcode: walletcode,
      balance: 0,
      recipients: %{},
      peers: peers}
    {:ok, walletstate}
  end

  def handle_call(:check_balance, _from, state) do
    IO.puts "#{state.miner}'s balance: #{state.balance} bitcoins"
    {:reply, state.balance, state}
  end

  def handle_cast({:income_money, amount}, state) do
    updated_state = %{state | balance: state.balance + amount}
    IO.puts "#{amount} bitcoins has been added into #{updated_state.miner}'s wallet, current balance is #{updated_state.balance}"
    {:noreply, updated_state}
  end

  def handle_cast({:add_peer, peer}, state) do
    {peername, peerpid} = peer
    state = %{state | peers: Map.put(state.peers, peername, peerpid)}
    #IO.puts "#{walletstate.owner} wallet peers=#{inspect walletstate.peers}"
    {:noreply, state}
  end

  def handle_cast({:add_recipient, recipient}, state) do
    {name, walletcode} = recipient
    state = %{state | recipients: Map.put(state.recipients, name, walletcode)}
    #IO.puts "#{walletstate.owner} wallet recipients=#{inspect walletstate.recipients}"
    {:noreply, state}
  end

  def handle_cast(:make_random_tx, state) do
    {peername, peerpid} = Enum.random(state.peers)
    receiver = Map.get(state.recipients, peername)
    #send 5% of my balance to a peer
    tx = Transaction.new(state.walletcode, receiver, 0.05 * state.balance , 0)
    tx = %{tx | hash: Transaction.crypto_hash(tx)}
    updated_state = %{state | balance: 0.95 * state.balance}
    #IO.puts "#{state.miner} make tx with #{peername} amount #{0.01 * state.balance}"
    Enum.each(updated_state.peers, fn {peername, peerpid} -> GenServer.cast(peerpid, {:new_tx, tx})  end)
    GenServer.cast(Monitor, {:new_tx, tx})
    {:noreply, updated_state}
  end

  def handle_cast({:make_targeted_tx, receivername, amount}, state) do
    IO.puts "#{state.miner} is making targeted transaction with #{amount} bitcoins to #{receivername}"
    receiver = Map.get(state.recipients, receivername)
    tx = Transaction.new(state.walletcode, receiver, amount , 0)
    tx = %{tx | hash: Transaction.crypto_hash(tx)}
    updated_state = %{state | balance: state.balance - amount}
    Enum.each(updated_state.peers, fn {peername, peerpid} -> GenServer.cast(peerpid, {:new_tx, tx})  end)
    GenServer.cast(Monitor, {:new_tx, tx})
    {:noreply, updated_state}
  end


end
