defmodule Cryptest.HTTPRouter do
  use Plug.Router
  use Plug.ErrorHandler

  plug Plug.Parsers, parsers: [:urlencoded, :multipart]

  plug :match
  plug :dispatch

  get "/" do
    main_page(conn)
  end

  post "/" do
    if Map.has_key?(conn.params, "msg") do
      Cryptest.Chat.send(conn.params["msg"])
    end
    if Map.has_key?(conn.params, "nick") do
      Cryptest.Identity.set_nickname(conn.params["nick"])
    end
    if Map.has_key?(conn.params, "peer") do
      [ipstr, portstr] = String.split(conn.params["peer"], ":")
      {:ok, ip} = :inet.parse_address (to_charlist ipstr)
      {port, _} = Integer.parse portstr
      Cryptest.TCPServer.add_peer(ip, port)
    end

    main_page(conn)
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end

  def main_page(conn) do
    {:ok, messages, _} = GenServer.call(Cryptest.ChatLog, {:read, nil, 42})

    msgtxt = messages
    |> Enum.map(fn {ts, nick, msg} -> "#{ts |> DateTime.from_unix! |> DateTime.to_iso8601} &lt;#{nick}&gt; #{msg}\n" end)

    peerlist = Cryptest.ConnSupervisor
    |> DynamicSupervisor.which_children
    |> Enum.map(fn {_, pid, _, _} -> "#{GenServer.call(pid, :get_host_str)}\n" end)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, "<pre>#{msgtxt}</pre>" <>
                      "<form method=POST><input type=text name=msg /><input type=submit value=send /></form>" <>
                      "<form method=POST><input type=text name=nick value=\"#{Cryptest.Identity.get_nickname}\" /><input type=submit value=\"change nick\" /></form>" <>
                      "<hr/><pre>#{peerlist}</pre>" <>
                      "<form method=POST><input type=text name=peer /><input type=submit value=\"add peer\" /></form>")
  end
end
