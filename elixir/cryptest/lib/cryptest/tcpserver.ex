defmodule Cryptest.TCPServer do
  require Logger
  use Task, restart: :permanent

  def start_link(port) do
    Task.start_link(__MODULE__, :accept, [port])
  end


  @doc """
  Starts accepting connections on the given `port`.
  """
  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port,
                      [:binary, packet: 2, active: false, reuseaddr: true])
    Logger.info "Accepting connections on port #{port}"
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = DynamicSupervisor.start_child(Cryptest.ConnSupervisor, {Cryptest.TCPConn, %{socket: client}})
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  def add_peer(ip, port) do
    {:ok, client} = :gen_tcp.connect(ip, port, [:binary, packet: 2, active: false])
    {:ok, pid} = DynamicSupervisor.start_child(Cryptest.ConnSupervisor, {Cryptest.TCPConn, %{socket: client}})
    :ok = :gen_tcp.controlling_process(client, pid)
    pid
  end

end

