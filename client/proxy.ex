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
  It's state is a tuple of {socket, Map: group_name => List(nicks)}
  """
  require Logger
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  @impl true
  def init(socket) do
    {:ok, {socket, Map.new()}}
  end

  @impl true
  def terminate(_reason, state) do
    Chat.Server.logout()
  end

  # Accept the data through the socket as they are delivered to the mailbox
  # with the :tcp atom (hybrid tcp server)
  @impl true
  def handle_info({:tcp, socket, data}, state) do
    :inet.setopts(socket, active: :once) # reset hybrid activation
    Logger.info("Proxy(#{inspect(self())}) received: #{inspect(data)}")
    process_data(data, state)
    {:noreply, state}
  end

  # Handles the closing of the tcp connection
  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    :gen_tcp.close(socket)
    Logger.info("Proxy(#{inspect(self())}) closing")
    {:stop, :normal, state}
  end

  # Handles receiving the msg from another user
  @impl true
  def handle_info({:msg, msg}, {socket, _} = state) do
    :inet.setopts(socket, active: :once)
    :gen_tcp.send(socket, msg <> "\n")
    {:noreply, state}
  end

  # Handles adding groups
  @impl true
  def handle_info({:grp, group_name, user_lst}, {socket, group_map} = state) do
    if not Regex.match?(~r/^#[a-zA-Z][a-zA-Z0-9_]{0,9}$/, group_name) do
      err_msg =
        """
        Invalid group name.
        Must start with hash (#), then a letter, include only alphanumeric chars and underscores,
        and have a max length of 11 (including the hash (#)).
        """
      Logger.alert("Proxy worker(pid(#{inspect(self())})): #{err_msg}")
      :gen_tcp.send(socket, err_msg <> "\n")
      {:noreply, state}
    else
      res = "Group \#{group_name} added."
      Logger.info("Proxy worker(pid(#{inspect(self())})): #{res}")
      :gen_tcp.send(socket, res)
      {:noreply, {socket, Map.put(group_map, group_name, user_lst)}}
    end
  end

  # * HELPER FUNCTIONS & HANDLERS

  defp process_data(data, {socket, group_map}) do
    parts = data |> String.trim |> String.split(~r/\s+/, parts: 3, trim: true)
    cmd = Enum.at(parts, 0, "")
    arg1 = Enum.at(parts, 1)
    arg2 = Enum.at(parts, 2)

    cond do
      Regex.match?(~r/^\/NCK$/i, cmd) && length(parts) > 1 ->
        handle_nck(socket, arg1)
      Regex.match?(~r/^\/LST$/i, cmd) ->
        handle_lst(socket)
      Regex.match?(~r/^\/MSG$/i, cmd) && length(parts) > 2 ->
        dest_lst = String.split(arg1, ",", trim: true)
        handle_msg(socket, group_map, dest_lst, arg2)
      Regex.match?(~r/^\/GRP$/i, cmd) && length(parts) > 2 ->
        user_lst = String.split(arg2, ",", trim: true)
        # Send msg because we need to update the full state
        send(self(), {:grp, arg1, user_lst})
      true ->
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

  defp handle_msg(_socket, _group_map, [], _msg), do: :ok

  defp handle_msg(socket, group_map, [dest | t], msg) do
    handle_msg(socket, group_map, dest, msg)
    handle_msg(socket, group_map, t, msg)
  end

  defp handle_msg(socket, group_map, dest, msg) do
    if group?(dest) do
      case Map.fetch(group_map, dest) do
        {:ok, nick_list} -> handle_msg(socket, group_map, nick_list, msg)
        _ ->
          err_msg = "#{dest} group was not found."
          Logger.info("Proxy worker(pid(#{inspect(self())})): #{err_msg}")
          :gen_tcp.send(socket, err_msg <> "\n")
      end
    else
      case Chat.Server.msg(dest, msg) do
        :ok -> :gen_tcp.send(socket, "Sent!" <> "\n")
        {:error, err_msg} ->
          :gen_tcp.send(socket, "Error sending to #{dest}: #{String.trim(err_msg)}" <> "\n")
      end
    end
  end

  defp group?(dest) do
    Regex.match?(~r/^#[a-zA-Z][a-zA-Z0-9_]{0,9}$/, dest)
  end

end
