defmodule Cryptest.Identity do
  use Agent
  require Salty.Sign.Ed25519, as: Sign

  def start_link(_) do
    Agent.start_link(__MODULE__, :init, [], name: __MODULE__)
  end

  def init() do
    {:ok, pk, sk} = Sign.keypair
    nick_suffix = pk
                  |> binary_part(0, 3)
                  |> Base.encode16
                  |> String.downcase
    %{
      keypair:  {pk, sk},
      nickname: "Anon" <> nick_suffix,
    }
  end

  def get_keypair() do
    Agent.get(__MODULE__, &(&1.keypair))
  end

  def get_nickname() do
    Agent.get(__MODULE__, &(&1.nickname))
  end

  def set_nickname(newnick) do
    Agent.update(__MODULE__, &(%{&1 | nickname: newnick}))
  end
end
