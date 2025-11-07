defmodule Chat.Client do
  def main(args) do
    host = ~c/127.0.0.1/
    port = parse_port(args, 6666)

    # Connect to server
    {:ok, socket} = :gen_tcp.connect(host, port, [:binary, active: false])

    IO.inspect("Connected to #{host}:#{port}")

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
    IO.write("> ")
    case IO.gets("") do
      :eof ->
        :ok
      line ->
        case String.trim(line) do
          "" ->
            # Do one last check before looping
            # recv(socket, packet_size, timeout_ms)
            case :gen_tcp.recv(socket, 0, 0) do
              {:ok, data} ->
                IO.puts(String.trim(data))
                loop(socket)
              _ ->
                loop(socket)
            end
          trimmed_line ->
            :ok = :gen_tcp.send(socket, trimmed_line <> "\n")

            # 0 = receives all bytes
            case :gen_tcp.recv(socket, 0) do
              {:ok, data} ->
                IO.puts(String.trim(data))
                loop(socket)

              {:error, :closed} ->
                IO.puts("Server closed the connection")
            end
        end
    end
  end
end

Chat.Client.main(System.argv())
