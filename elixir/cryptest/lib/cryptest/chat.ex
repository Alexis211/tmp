defmodule Cryptest.Chat do
  def send(msg) do
    msgitem = {(System.os_time :seconds),
               Cryptest.Identity.get_nickname(),
               msg}
    GenServer.cast(Cryptest.ChatLog, {:insert, msgitem})

    Cryptest.ConnSupervisor
    |> DynamicSupervisor.which_children
    |> Enum.each(fn {_, pid, _, _} -> GenServer.cast(pid, :init_push) end)
  end

  def msg_callback({ts, nick, msg}) do
    IO.puts "#{ts |> DateTime.from_unix! |> DateTime.to_iso8601} <#{nick}> #{msg}"
  end

  def msg_cmp({ts1, nick1, msg1}, {ts2, nick2, msg2}) do
    Cryptest.MerkleList.cmp_ts_str({ts1, nick1<>"|"<>msg1}, 
                                   {ts2, nick2<>"|"<>msg2})
  end 
end
