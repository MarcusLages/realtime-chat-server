defmodule Chat.Proxy do
  @moduledoc """
  Module used to open the Chat.Server service through the use of sockets.
  Default port of value of 6666.
  Each connection creates a new Chat.Proxy.Worker reponsible for dealing with
  requests from that connection/socket.
  """
  require Logger
  use GenServer

  def start_link(port \\ 6666) do
    GenServer.start_link(__MODULE__, port)
  end

  # Start listening socket at "port"
  @impl true
  def init(port) do
    opts = [:binary, active: :once, packet: :line, reuseaddr: true]
    case :gen_tcp.listen(port, opts) do
      {:ok, listen_socket} ->
        Logger.info("Starting proxy server at port #{port}")
        :inet.setopts(listen_socket, active: :once) # reset active tcp
        send(self(), :accept)
        {:ok, listen_socket}
      {:error, reason} ->
        Logger.info("Error starting proxy.\nReason: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  # "route" :accept will be used to keep looping and accepting new accept sockets
  @impl true
  def handle_info(:accept, listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        {:ok, pid} = Chat.Proxy.Worker.start_link(socket)
        :gen_tcp.controlling_process(socket, pid)
        Logger.info("Starting proxy worker(pid(#{inspect(pid)})) for socket.")
        send(self(), :accept)
        {:noreply, listen_socket}
      {:error, reason} ->
        Logger.info("Error handling accepting socket.\nReason: #{inspect(reason)}")
        {:stop, reason, listen_socket}
    end
  end

end

defmodule Chat.Proxy.Worker do
  @moduledoc """
  Module used to handle a socket connection with an accept socket so it can use
  the functionalities of Chat.Server.
  Should be created by Chat.Proxy.
  """
  require Logger
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    {:ok, socket}
  end

  # Accept the data through the socket as they are delivered to the mailbox
  # with the :tcp atom (hybrid tcp server)
  @impl true
  def handle_info({:tcp, socket, data}, socket) do
    :inet.setopts(socket, active: :once)
    Logger.info("Proxy(#{inspect(self())}) received: #{inspect(data)}")
    process_data(data, socket)
    {:noreply, socket}
  end

  # Handles the closing of the tcp connection
  @impl true
  def handle_info({:tcp_closed, socket}, socket) do
    :gen_tcp.close(socket)
    {:stop, :normal, socket}
  end

  # Handles receiving the msg from another user
  @impl true
  def handle_info({:msg, msg}, socket) do
    :inet.setopts(socket, active: :once)
    :gen_tcp.send(socket, msg <> "\n")
    {:noreply, socket}
  end

  # * HELPER FUNCTIONS & HANDLERS

  defp process_data(data, socket) do
    case String.split(data, ~r/\s+/, parts: 3, trim: true) do
      ["/NCK", nick | _] -> handle_nck(socket, nick)
      ["/LST" | _] -> handle_lst(socket)
      ["/MSG", dest, msg] ->
        dest_lst = String.split(dest, ",", trim: true)
        handle_msg(socket, dest_lst, msg)
      ["/GRP", group, users] ->
        user_lst = String.split(users, ",", trim: true)
        handle_grp(socket, group, user_lst)
      _ ->
        err_msg = "Bad request - Invalid or missing command or argument(s): #{data}"
        Logger.alert("Proxy worker(pid(#{inspect(self())})): #{err_msg}")
        :gen_tcp.send(socket, err_msg <> "\n")
    end
  end

  defp handle_nck(socket, nick) do
    case Chat.Server.nck(nick) do
      :ok -> :gen_tcp.send(socket, "Nickname #{nick} registered!" <> "\n")
      {:error, err_msg} -> :gen_tcp.send(socket, err_msg <> "\n")
    end
  end

  defp handle_lst(socket) do
    users = Enum.join(Chat.Server.lst(), ", ")
    :gen_tcp.send(socket, "Users: #{users}" <> "\n")
  end

  defp handle_msg(_socket, [], _msg), do: :ok

  defp handle_msg(socket, [dest | t], msg) do
    handle_msg(socket, dest, msg)
    handle_msg(socket, t, msg)
  end

  defp handle_msg(socket, dest, msg) do
    cond do
      group?(dest) ->
        # TODO
        :ok
      true ->
        case Chat.Server.msg(dest, msg) do
          :ok -> :gen_tcp.send(socket, "Sent!" <> "\n")
          {:error, err_msg} -> :gen_tcp.send(socket, "Error sending to #{dest}: #{err_msg}" <> "\n")
        end
    end
  end

  defp handle_grp(socket, group, users) do
    #TODO
  end

  defp group?(dest) do
    false
  end

end
