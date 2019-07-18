defmodule Bitcoin.Transaction do
  @moduledoc false

  defstruct [:timestamp, :sender, :receiver, :amount, :txfee, :hash]

  def new(sender, receiver, amount, fee) do
    %Bitcoin.Transaction{
      sender: sender,
      receiver: receiver,
      amount: amount,
      txfee: fee,
      timestamp: NaiveDateTime.utc_now
    }
  end

  def crypto_hash(%{} = transaction) do
    Map.take(transaction, [:timestamp, :sender, :receiver, :amount, :txfee])
    |> Poison.encode!
    |> sha256()
  end

  defp sha256(binary) do
    :crypto.hash(:sha256, binary) |> Base.encode16
  end

end
