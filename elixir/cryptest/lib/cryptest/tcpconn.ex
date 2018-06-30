defmodule Cryptest.TCPConn do
  use GenServer, restart: :temporary
  require Salty.Box.Curve25519xchacha20poly1305, as: Box
  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    GenServer.cast(self(), :handshake)
  	{:ok, state}
  end

  def handle_cast(:handshake, state) do
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
    Logger.info "New peer: #{inspect cli_pkey} at #{inspect addr}:#{port}"

    :inet.setopts(socket, [active: true])

    {:noreply,
      %{ socket: socket,
        my_pkey: srv_pkey,
        my_skey: srv_skey,
        his_pkey: cli_pkey,
        conn_my_pkey: sess_pkey,
        conn_my_skey: sess_skey,
        conn_his_pkey: cli_sess_pkey
      }
	  }
  end

  defp encode_pkt(pkt, pk, sk) do
    {:ok, n} = Salty.Random.buf Box.noncebytes
    {:ok, msg} = Box.easy(pkt, n, pk, sk)
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
    :gen_tcp.send(state.socket, enc)
  end

  def handle_info({:tcp, _socket, _ip, _port, raw_data}, state) do
    msg = decode_pkt(raw_data, state.conn_his_pkey, state.conn_my_skey)
    handle_packet(:erlang.binary_to_term(msg, {:safe}), state)
  end

  defp handle_packet(msg, state) do
    Logger.info "Message: #{inspect msg}"
    state
  end
end
