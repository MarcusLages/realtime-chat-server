defmodule Chat.Proxy do
  @moduledoc """
  Module used to open the Chat.Server service through the use of sockets.
  Default port of value of 6666.
  Each connection creates a new Chat.Proxy.Worker reponsible for dealing with
  requests from that connection/socket.
  """
  require Logger
  use GenServer
  @name {:global, __MODULE__}

  def start_link(port \\ 6666) do
    GenServer.start_link(__MODULE__, port, name: @name)
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
    # TODO: process data
    {:noreply, socket}
  end

  # Handles the closing of the tcp connection
  @impl true
  def handle_info({:tcp_closed, socket}, socket) do
    :gen_tcp.close(socket)
    {:stop, :normal, socket}
  end

end
