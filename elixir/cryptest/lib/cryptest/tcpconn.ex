defmodule Cryptest.TCPConn do
  require GenServer
  require Salty.Box.Curve25519xchacha20poly1305, as: Box
  require Logger

  def init(state) do
    socket = state.socket

    {:ok, srv_pkey, srv_skey} = Cryptest.Keypair.get
    {:ok, sess_pkey, sess_skey} = Box.keypair

    # Exchange node public keys
    :gen_tcp.send(socket, srv_pkey)  
    {:ok, cli_pkey} = :gen_tcp.recv(socket, 0)

    # Exchange session public keys
    pkt = encode_pkt(sess_pkey, cli_pkey, srv_skey)
    :gen_tcp.send(socket, pkt)

    {:ok, pkt} = :gen_tcp.recv(socket, 0)
    cli_sess_pkey = decode_pkt(pkt, cli_pkey, srv_skey)

    # Connected
    {:ok, {addr, port}} = :inet.peername socket
    Logger.info "New peer: #{cli_pkey} at #{addr}:#{port}"

    :gen_tcp.setopts(socket, [active: true])

    { socket: socket,
      my_pkey: srv_pkey,
      my_skey: srv_skey,
      his_pkey: cli_pkey,
      conn_my_pkey: sess_pkey,
      conn_my_skey: sess_skey,
      conn_his_pkey: cli_sess_pkey
    }
  end

  defp encode_pkt(pkt, pk, sk) do
    {:ok, n} = Salty.Random.buf Box.noncebytes
    {:ok, msg} = Box.easy(msg, n, pk, sk)
    n <> msg
  end

  defp decode_pkt(pkt, pk, sk) do
    n = binary_part(pkt, 0, Box.noncebytes)
    enc = binary_part(pkt, Box.noncebytes, (byte_size pkt) - Box.noncebytes)
    {:ok, msg} = Box.open_easy(enc, n, pk, sk)
    msg
  end

  defp send_msg(state, msg) do
    msgbin = :erlang.term_to_binary msg
    enc = encode_pkt(msgbin, state.conn_his_pkey, state.conn_my_skey)
    :gentcp.send(state.socket, enc)
  end

  def handle_info({:tcp, socket, ip, port, raw_data}, state) do
    msg = decode_pkt(raw_data, state.conn_his_pkey, state.conn_my_skey)
    handle_packet(:erlang.binary_to_term(msg, {:safe}), state)
  end

  defp handle_packet(msg, state) do
    Logger.info "Message: #{inspect msg}"
    state
  end
end
