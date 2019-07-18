defmodule Bitcoin.Block do
  @moduledoc false

  alias Bitcoin.Blockcrypto, as: Blockcrypto

  defstruct [:prev_hash, :hash, :timestamp, :nonce, :data]

  def new(data, prev_hash) do
    %Bitcoin.Block{
      data: data,
      prev_hash: prev_hash,
      timestamp: NaiveDateTime.utc_now,
    }
  end

  #the initial block for each peer
  def first() do
    %Bitcoin.Block{
      data: [],
      prev_hash: "",
      timestamp: NaiveDateTime.utc_now,
    }
  end


  def valid_block?(%Bitcoin.Block{} = block) do
    Blockcrypto.hash(block) == block.hash
  end

  def valid_block?(%Bitcoin.Block{} = block, %Bitcoin.Block{} = prev_block) do
    (block.prev_hash == prev_block.hash) && valid_block?(block)
  end
end
