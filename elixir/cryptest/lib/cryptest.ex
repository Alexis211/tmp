defmodule Cryptest do
  @moduledoc """
  Documentation for Cryptest.
  """

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      # Starts a worker by calling: Cryptest.Worker.start_link(arg1, arg2, arg3)
      # worker(Cryptest.Worker, [arg1, arg2, arg3]),
      Cryptest.Keypair,
      { DynamicSupervisor, name: Cryptest.ConnSupervisor, strategy: :one_for_one, restart: :temporary },
      { Task, fn -> Cryptest.TCPServer.accept(4044) end },
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cryptest.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
