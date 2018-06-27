defmodule Cryptest.TCPServer do
  require Logger
  require Salty.Box.Curve25519xchacha20poly1305, as: Box

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
    {:ok, pid} = Task.Supervisor.start_child(Cryptest.ConnSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    {:ok, srv_pkey, srv_skey} = Cryptest.Keypair.get

    :gen_tcp.send(socket, srv_pkey)  
    {:ok, cli_pkey} = :gen_tcp.recv(socket, 0)

    {:ok, sess_pkey, sess_skey} = Box.keypair
    sendmsg(socket, sess_pkey, cli_pkey, srv_skey)
    cli_sess_pkey = recvmsg(socket, cli_pkey, srv_skey)

    sendmsg(socket, "Hello, world!", cli_sess_pkey, sess_skey) 
    hello = recvmsg(socket, cli_sess_pkey, sess_skey)
    IO.puts(hello)
  end

  defp sendmsg(socket, msg, pk, sk) do
    {:ok, n} = Salty.Random.buf Box.noncebytes
    {:ok, msg} = Box.easy(msg, n, pk, sk)
    :gen_tcp.send(socket, n <> msg)
  end

  defp recvmsg(socket, pk, sk) do
    {:ok, pkt} = :gen_tcp.recv(socket, 0)
    n = binary_part(pkt, 0, Box.noncebytes)
    enc = binary_part(pkt, Box.noncebytes, (byte_size pkt) - Box.noncebytes)
    {:ok, msg} = Box.open_easy(enc, n, pk, sk)
    msg
  end
end

