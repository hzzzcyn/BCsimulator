defmodule Bitcoin.Blockchain do
  @moduledoc false

  alias Bitcoin.Blockcrypto, as: Blockcrypto
  alias Bitcoin.Block, as: Block

  def new() do
    [ Blockcrypto.hash_and_add(Block.first()) ]
  end

  def add_new_block_into_blockchain(blockchain, data) do
    %Block{hash: prev_hash} = hd(blockchain)
    newblock = Block.new(data, prev_hash) |> Blockcrypto.hash_and_add()
    [newblock | blockchain]
  end

  #determine whether a blockchain is valid
  def valid_blockchain?(blockchain) do
    beginning_block =
      Enum.reduce_while(blockchain, nil, fn (prev, current) ->
        cond do
          current == nil ->
            {:cont, prev}

          Block.valid_block?(current, prev) ->
            {:cont, prev}

          true ->
            {:halt, false}
        end
    end)

    if beginning_block do
      Block.valid_block?(beginning_block)
    else
      false
    end
  end
end
