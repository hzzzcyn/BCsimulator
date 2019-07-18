defmodule Bitcoin.Miner do
  @moduledoc false
  alias Bitcoin.Block, as: Block
  alias Bitcoin.Blockchain, as: Blockchain
  alias Bitcoin.Wallet, as: Wallet
  alias Bitcoin.Blockcrypto, as: Blockcrypto
  alias Bitcoin.Monitor
  use GenServer
  use Bitwise

  defmodule Minerstate do
    defstruct [:bosspid, :numZeros, :peers, :blockchain, :txpool, :miningpid, :walletpid, :name]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, [])
  end

  def join(pid, first_peer_pid) do
    GenServer.cast(pid, {:join, first_peer_pid})
  end

  def make_random_tx(senderpid) do
    GenServer.cast(senderpid, :make_random_tx)
  end

  def make_tx_to(senderpid, receivername, amount) do
    GenServer.cast(senderpid, {:make_targeted_tx, receivername, amount})
  end

  def check_balance(pid) do
    GenServer.call(pid, :check_balance)
  end

  def check_blockchain(pid) do
    GenServer.call(pid, :check_blockchain)
  end

  def get_peers(pid) do
    GenServer.call(pid, :get_peers)
  end

  def print_peers(pid) do
    GenServer.call(pid, :print_peers)
  end

  def test_miner(pid) do
    GenServer.call(pid, :test_miner)
  end

  def verify_block(pid, block) do
    GenServer.call(pid, {:verify_block, block})
  end

  def add_new_peer(pid, newpeer_name, newpeer_pid, newpeer_walletcode) do
    GenServer.cast(pid, {:add_newpeer, newpeer_name, newpeer_pid, newpeer_walletcode})
  end

  def add_new_block(pid, newblock) do
    GenServer.cast(pid, {:add_newblock, newblock})
  end

  def init(args) do
    {bosspid, numZeros, name} = args
    blockchain = Blockchain.new()
    peers = %{}
    minerstate = %Minerstate{
      bosspid: bosspid,
      numZeros: numZeros,
      peers: peers,
      blockchain: blockchain,
      txpool: [],
      name: name}
    walletcode = get_walletcode(name)
    {:ok, walletpid} = Wallet.start_link({name, self(), walletcode, peers})
    minerstate = %{minerstate | walletpid: walletpid}
    miners = ["Peer9", "Peer19", "Peer29", "Peer39", "Peer49", "Peer59", "Peer69"]
    if Enum.member?(miners, name) do
      send self(), :mining
    end
    {:ok, minerstate}
  end


  def handle_call({:verify_block, block}, _from, minerstate) do
    blockchain = Blockchain.add_new_block_into_blockchain(minerstate.blockchain, block.data)
    # it is the next block and the nonce is valid
    is_verified = Blockchain.valid_blockchain?(blockchain) and verify(block, minerstate.numZeros)
    {:reply, is_verified, minerstate}
  end

  def handle_call(:check_balance, _from, minerstate) do
    {:reply, Wallet.check_balance(minerstate.walletpid), minerstate}
  end

  def handle_call(:check_blockchain, _from, minerstate) do
    IO.puts "#{minerstate.name}'s blockchain length=#{length(minerstate.blockchain)} "
    {:reply, minerstate.blockchain, minerstate}
  end

  def handle_call(:test_miner, _from, minerstate) do
    IO.inspect(minerstate)
    {:reply, minerstate, minerstate}
  end

  def handle_call(:get_peers, _from, minerstate) do
    {:reply, Map.put(minerstate.peers, minerstate.name, self()), minerstate}
  end

  def handle_call(:print_peers, _from, minerstate) do
    IO.inspect(minerstate.peers)
    {:reply, minerstate.peers, minerstate}
  end

  @doc """
  after being created, each peer will join into the network
  """
  def handle_cast({:join, first_peer_pid}, minerstate) do
    peers = get_peers(first_peer_pid)
    cur_peer_walletcode = get_walletcode(minerstate.name)
    Enum.each(peers, fn {peername, pid} ->
      add_new_peer(pid, minerstate.name, self(), cur_peer_walletcode)    #add current peer info into other peers
      Wallet.add_peer(minerstate.walletpid, {peername, pid})
      peer_walletcode =  get_walletcode(peername)
      Wallet.add_recipient(minerstate.walletpid, {peername, peer_walletcode})
    end)
    minerstate = %{minerstate | peers: peers}
    #IO.puts "#{state.name} join network, peers=#{inspect state.peers}"
    {:noreply, minerstate}
  end


  def handle_cast({:add_newpeer, newpeer_name, newpeer_pid, newpeer_walletcode}, minerstate) do
    peers = minerstate.peers
    if Map.has_key?(peers, newpeer_name) do
      {:noreply, minerstate}
    else
      minerstate = %{minerstate | peers: Map.put(peers, newpeer_name, newpeer_pid)}
      Wallet.add_peer(minerstate.walletpid, {newpeer_name, newpeer_pid})
      Wallet.add_recipient(minerstate.walletpid, {newpeer_name, newpeer_walletcode})
      {:noreply, minerstate}
    end
  end

  @doc """
  after a new block was verified, all peers will stop their current mining and add this new block into their blockchain
  """
  def handle_cast({:add_newblock, block}, minerstate) do
    #kill current mining process
    if !is_nil(minerstate.miningpid) and Process.alive?(minerstate.miningpid) do
      IO.puts "#{minerstate.name} aborts current mining and go to mine a new block."
      Process.exit(minerstate.miningpid, :normal)
    end

    #check if new block contains my current mining tx
    minerstate = %{minerstate | blockchain: Blockchain.add_new_block_into_blockchain(minerstate.blockchain, block.data) }
    tx_hash_list = Enum.map(block.data, fn x -> x.hash end)
    updated_minerstate = %{minerstate | txpool: Enum.filter(minerstate.txpool, fn x -> !Enum.member?(tx_hash_list, x.hash) end )}

    # adjust wallet balance if tx is about current node.
    Enum.each(block.data, fn tx ->
      if tx.receiver == get_walletcode(updated_minerstate.name) do
        Wallet.add_money(updated_minerstate.walletpid, tx.amount)
      end
    end)
    IO.puts "After adding a new block, #{updated_minerstate.name}'s blockchain length is #{length(updated_minerstate.blockchain)}"
    {:noreply, updated_minerstate}
  end


  @doc """
  all peers will verify the new block whenever it is mined by any peer
  reward will be earned and transaction pool, blockchain will be updated
  """
  def handle_cast({:newblock_mined, block}, minerstate) do
    #IO.puts "#{state.name} mined new block!"
    # send to some nodes to validate block
    minerstate =
      if Enum.all?(minerstate.peers, fn {peername, peerpid} -> verify_block(peerpid, block) end) do
        IO.puts "#{minerstate.name} mined a new block, earned 20 bitcoins"
        Wallet.add_money(minerstate.walletpid, 20)
        # broadcast valid block to all peers
        Enum.each(minerstate.peers, fn {peername, peerpid} -> add_new_block(peerpid, block)  end )
        GenServer.cast(Monitor, {:new_block, block})
        # adjust wallet balance if tx is about current node.
        Enum.each(block.data, fn tx ->
          if tx.receiver == get_walletcode(minerstate.name) do
            Wallet.add_money(minerstate.walletpid, tx.amount)
          end
        end)
        {receivername, receiverpid} = Enum.random(minerstate.peers)
        make_tx_to(self(), receivername, 5)
        tx_hash_list = Enum.map(block.data, fn x -> x.hash end)

        updated_minerstate = %{minerstate | txpool: Enum.filter(minerstate.txpool, fn x -> !Enum.member?(tx_hash_list, x.hash) end )}
        updated_minerstate = %{updated_minerstate | blockchain: Blockchain.add_new_block_into_blockchain(minerstate.blockchain, block.data) }
        updated_minerstate
      else
        minerstate
      end
    #IO.puts "#{state.name} blockchain=#{inspect state.blockchain}"
    {:noreply, minerstate}
  end

  def handle_cast(:make_random_tx, minerstate) do
    Wallet.make_random_tx(minerstate.walletpid)
    {:noreply, minerstate}
  end

  def handle_cast({:make_targeted_tx, receivername, amount}, minerstate) do
    Wallet.make_targeted_tx(minerstate.walletpid, receivername, amount)
    {:noreply, minerstate}
  end


  def handle_cast({:new_tx, tx}, minerstate) do
    updated_minerstate = %{minerstate | txpool: [tx | minerstate.txpool]}
    {:noreply, updated_minerstate}
  end

  @doc """
  Once transaction pool size is larger than 8, spwan a process to mine
  """
  def handle_info(:mining, minerstate) do
    minerstate =
      if length(minerstate.txpool) >= 8 do

        [topblock | tail] = minerstate.blockchain
        block = Block.new(Enum.take(minerstate.txpool, 8), topblock.hash)
        minerpid = self()
        # create new process to mining new block
        %{minerstate | miningpid:  spawn fn -> mining(block, minerstate.numZeros, minerpid, minerstate.name) end}
      else
        minerstate
      end
    Process.send_after self(), :mining, 10000
    {:noreply, minerstate}
  end

  @doc """
  mining details
  """
  def mining(%Block{} = block, numZeros, minerpid, minername) do
    Process.sleep(:rand.uniform(20))
    binary_string = Blockcrypto.parse_into_binary(block)
    block = %{block | nonce: proof_of_work(binary_string, numZeros)}
    GenServer.cast(minerpid, {:newblock_mined, block})
  end


  def get_walletcode(name) do
    hash(name <> "wallet") |> Base.encode16
  end

  def verify(%Block{} = block, numZeros) do
    binary = Blockcrypto.parse_into_binary(block) <> Integer.to_string(block.nonce)
    hashvalue = hash(binary)
    verify_proof_of_work(hashvalue, numZeros)
  end

  def proof_of_work(binary_key, numZeros) do
    proof_of_work_helper(binary_key, :rand.uniform(100), numZeros);
  end

  defp proof_of_work_helper(key, nonce, numZeros) do
    hashvalue = hash(key <> Integer.to_string(nonce))
    if verify_proof_of_work(hashvalue, numZeros) do
      nonce
    else
      proof_of_work_helper(key, nonce + 1, numZeros)
    end
  end

  defp verify_proof_of_work(hashvalue, numZeros) do
    # Convert m bits to a multiple of 8
    numBits = (div(numZeros, 8) + 1) * 8
    # get the first numBytes*8 bits of value from hashcode
    << header :: size(numBits), _ :: binary >> = hashvalue
    # shift
    leadingDigits = header >>>  (numBits - numZeros)

    leadingDigits == 0
  end

  def hash(key) do
    :crypto.hash(:sha256, key)
  end

  def measure(function) do
    function
    |> :timer.tc
    |> elem(0)
    |> Kernel./(1_000_000)
  end

end
