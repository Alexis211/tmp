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
    msg = {(System.os_time :seconds), conn.params["v"]}
    GenServer.cast(Cryptest.ChatLog, {:insert, msg})

    Cryptest.ConnSupervisor
    |> DynamicSupervisor.which_children
    |> Enum.each(fn {_, pid, _, _} -> GenServer.cast(pid, :init_push) end)

    main_page(conn)
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end

  def main_page(conn) do
    {:ok, messages, _} = GenServer.call(Cryptest.ChatLog, {:read, nil, 42})

    msgtxt = messages
    |> Enum.map(fn {_ts, msg} -> "#{msg}\n" end)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, "<pre>#{msgtxt}</pre><form method=POST><input type=text name=v /><input type=submit value=send /></form>")
  end
end
