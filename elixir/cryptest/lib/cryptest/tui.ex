defmodule Cryptest.TUI do
  def run() do
    str = "say: " |> IO.gets |> String.trim
    cond do
      str == "/quit" ->
        nil
      String.slice(str, 0..0) == "/" ->
        command = str |> String.slice(1..-1) |> String.split(" ")
        handle_command(command)
        run()
      true -> 
        Cryptest.Chat.send(str)
        run()
    end
  end

  def handle_command(["connect", ipstr, portstr]) do
    {:ok, ip} = :inet.parse_address (to_charlist ipstr)
    {port, _} = Integer.parse portstr
    Cryptest.TCPServer.add_peer(ip, port)
  end

  def handle_command(["nick", nick]) do
    Cryptest.Identity.set_nickname nick
  end

  def handle_command(_cmd) do
    IO.puts "Invalid command"
  end
end
