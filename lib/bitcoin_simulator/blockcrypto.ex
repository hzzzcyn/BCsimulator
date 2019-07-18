defmodule Bitcoin.Blockcrypto do
  @moduledoc false

  def hash(%{} = block) do
    parse_into_binary(block) |> sha256()
  end

  def parse_into_binary(%{} = block) do
    Map.take(block, [:data, :timestamp, :prev_hash]) |> Poison.encode!
  end

  def hash_and_add(%{} = block) do
    %{block | hash: hash(block)}
  end

  defp sha256(binary) do
    :crypto.hash(:sha256, binary) |> Base.encode16
  end
end
