defmodule CryptestTest do
  use ExUnit.Case
  doctest Cryptest

  require Salty.Box.Curve25519xchacha20poly1305, as: Box
  require Salty.Sign.Ed25519, as: Sign

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "crypto connection" do
    {:ok, srv_pkey, srv_skey} = Sign.keypair
    {:ok, sess_pkey, sess_skey} = Box.keypair
    {:ok, challenge} = Salty.Random.buf 32
    {:ok, socket} = :gen_tcp.connect {127,0,0,1}, 4044, [:binary, packet: 2, active: false]

    :gen_tcp.send(socket, srv_pkey <> sess_pkey <> challenge)  
    {:ok, pkt} = :gen_tcp.recv(socket, 0)
    cli_pkey = binary_part(pkt, 0, Sign.publickeybytes)
    cli_sess_pkey = binary_part(pkt, Sign.publickeybytes, Box.publickeybytes)
    cli_challenge = binary_part(pkt, Sign.publickeybytes + Box.publickeybytes, 32)

    {:ok, cli_challenge_sign} = Sign.sign_detached(cli_challenge, srv_skey)
    sendmsg(socket, cli_challenge_sign, cli_sess_pkey, sess_skey)

    challenge_sign = recvmsg(socket, cli_sess_pkey, sess_skey)
    :ok = Sign.verify_detached(challenge_sign, challenge, cli_pkey)

    pkt = :erlang.binary_to_term(recvmsg(socket, cli_sess_pkey, sess_skey), [:safe])
    IO.puts (inspect pkt)
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

  test "merkle list" do
    {:ok, pid} = GenServer.start(Cryptest.MerkleList, &Cryptest.MerkleList.cmp_ts_str/2)

    {:ok, list, rt} = GenServer.call(pid, {:read, nil, nil})
    assert list == []
    assert rt == nil

    GenServer.cast(pid, {:insert, {12, "aa, bb"}})
    GenServer.cast(pid, {:insert_many, [{14, "qwerty"}, {8, "haha"}]})
  end
end
