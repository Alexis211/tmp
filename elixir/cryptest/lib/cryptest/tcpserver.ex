defmodule Cryptest.TCPServer do
  require Logger

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
end

