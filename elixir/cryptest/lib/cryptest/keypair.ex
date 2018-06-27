defmodule Cryptest.Keypair do
  require Salty.Box.Curve25519xchacha20poly1305, as: Box
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> Box.keypair end, name: __MODULE__)
  end

  def get() do
    Agent.get(__MODULE__, &(&1))
  end
end
