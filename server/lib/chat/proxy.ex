defmodule Chat.Proxy do
  use GenServer
  @name {:global, __MODULE__}

  def start_link(port \\ 6666) do
    GenServer.start_link(__MODULE__, port, name: @name)
  end

  @impl true
  def init(port) do
    opts = [:binary, active: :once, packet: :line, reuseaddr: true]
    # Start main socket at "port"
    case :gen_tcp.listen(port, opts) do
      {:ok, listen_socket} ->
        IO.inspect("Starting proxy server at port #{port}")
        :inet.setopts(listen_socket, active: once) # reset active tcp
        send(self(), :accept)
        {:ok, listen_socket}
      {:error, reason} ->
        IO.inspect("Error starting proxy.\nReason: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:accept, listen_socket) do
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        {:ok, pid} = Chat.Proxy.Worker.start_link(socket)
        :gen_tcp.controlling_process(socket, pid)
        IO.inspect("Starting proxy worker(pid(#{inspect(pid)})) for socket.")
        send(self(), :accept)
        {:noreply, listen_socket}
      {:error, reason} ->
        IO.inspect("Error handling accepting socket.\nReason: #{inspect(reason)}")
        {:stop, reason, listen_socket}
    end
  end

end

defmodule Chat.Proxy.Worker do
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
    IO.inspect("Proxy(#{inspect(self())}) received: #{inspect(data)}")
    # TODO: process data
    {:noreply, socket}
  end

  @impl true
  def handle_info({:tcp_closed, socket}, socket) do
    :gen_tcp.close(socket)
    {:stop, :normal, socket}
  end

end
