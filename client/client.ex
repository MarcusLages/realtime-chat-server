defmodule Chat.Client do
  def main(args) do
    host = ~c/127.0.0.1/
    port = parse_port(args, 6666)

    # Connect to server
    {:ok, socket} = :gen_tcp.connect(host, port, [:binary, active: false])

    IO.inspect("Connected to #{host}:#{port}")

    parent = self()
    spawn(fn -> read_from_socket(socket, parent) end)
    spawn(fn -> read_from_keyboard(parent) end)

    loop(socket)
    :gen_tcp.close(socket)
  end

  defp parse_port([], default), do: default
  defp parse_port([port_str | _], _default) do
    case Integer.parse(port_str) do
      {port, _} -> port
      :error -> raise "Invalid port number"
    end
  end

  defp loop(socket) do
    receive do
      {:socket, msg} ->
        IO.write("\r")
        IO.puts(String.trim(msg))
        IO.write("> ")
        loop(socket)

      {:keyboard, msg} ->
        :gen_tcp.send(socket, String.trim(msg) <> "\n")
        loop(socket)

      {:closed, :socket} ->
        IO.puts("Server closed connection")

      {:closed, :keyboard} ->
        IO.puts("Keyboard closed")
    end
  end

  defp read_from_socket(socket, parent) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        send(parent, {:socket, data})
        read_from_socket(socket, parent)

      {:error, :closed} ->
        send(parent, {:closed, :socket})
    end
  end

  defp read_from_keyboard(parent) do
    IO.write("> ")
    case IO.gets("") do
      :eof ->
        send(parent, {:closed, :keyboard})
        # read_from_keyboard(parent)
      line ->
        trimmed = String.trim(line)
        if trimmed != "", do: send(parent, {:keyboard, trimmed})
        read_from_keyboard(parent)
    end
  end

end

Chat.Client.main(System.argv())
