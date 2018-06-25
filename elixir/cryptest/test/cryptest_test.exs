defmodule CryptestTest do
  use ExUnit.Case
  doctest Cryptest

  require Salty.Box.Curve25519xchacha20poly1305, as: Box

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "crypto connection" do
    {:ok, srv_pkey, srv_skey} = Box.keypair
    {:ok, socket} = :gen_tcp.connect {127,0,0,1}, 4044, [:binary, packet: 2, active: false]

    :gen_tcp.send(socket, srv_pkey)  
    {:ok, cli_pkey} = :gen_tcp.recv(socket, 0)

    {:ok, sess_pkey, sess_skey} = Box.keypair
    sendmsg(socket, sess_pkey, cli_pkey, srv_skey)
    cli_sess_pkey = recvmsg(socket, cli_pkey, srv_skey)

    sendmsg(socket, "World, hello!", cli_sess_pkey, sess_skey) 
    hello = recvmsg(socket, cli_sess_pkey, sess_skey)
    IO.puts(hello)
  end

  defp sendmsg(sock, msg, pk, sk) do
    {:ok, n} = Salty.Random.buf Box.noncebytes
    {:ok, msg} = Box.easy(msg, n, pk, sk)
    :gen_tcp.send(sock, n <> msg)
  end

  defp recvmsg(sock, pk, sk) do
    {:ok, pkt} = :gen_tcp.recv(sock, 0)
    n = binary_part(pkt, 0, Box.noncebytes)
    enc = binary_part(pkt, Box.noncebytes, (byte_size pkt) - Box.noncebytes)
    {:ok, msg} = Box.open_easy(enc, n, pk, sk)
    msg
  end
end
