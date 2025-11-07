defmodule Chat.Server do
  use GenServer
  @name {:global, __MODULE__}

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: @name)
  end

  def nck(nick) do
    GenServer.call(@name, {:nck, nick})
  end

  def msg(dest, msg) do
    GenServer.call(@name, {:msg, dest, msg})
  end

  def lst() do
    GenServer.call(@name, :lst)
  end

  #* /NCK
  @impl true
  def handle_call({:nck, nick}, {from_pid, _}, nick_pid_map) do
    if not Regex.match?(~r/^[a-zA-Z][a-zA-Z0-9_]{0,9}$/, nick) do
      res = {:error,
        """
        Invalid nickname.
        Must start with a letter, include only alphanumeric chars and underscores,
        and have a max length of 10.
        """
      }
      {:reply, res, nick_pid_map}
    else
      case Map.fetch(nick_pid_map, nick) do
        {:ok, pid} when pid != from_pid ->
          res = {:error, "Nickname already exists"}
          {:reply, res, nick_pid_map}
        _ ->
          new_map = nick_pid_map
            |> Map.filter(fn {_, v_pid} -> v_pid != from_pid end)
            |> Map.put(nick, from_pid)
          {:reply, :ok, new_map}
      end
    end
  end

  # * /MSG
  @impl true
  def handle_call({:msg, dest, msg}, {from_pid, _}, nick_pid_map) do
    case Enum.find(nick_pid_map, fn {_, v} -> v === from_pid end) do
      {nick, ^from_pid} ->
        case Map.fetch(nick_pid_map, dest) do
          {:ok, dest_pid} ->
            send(dest_pid, nick <> ": " <> msg)
            {:reply, :ok, nick_pid_map}
          _ ->
            res = {:error, "Destination nickname not found"}
            {:reply, res, nick_pid_map}
        end
      _ ->
        res = {:error, "You must have a nickname first"}
        {:reply, res, nick_pid_map}
    end
  end

  #* /LST
  @impl true
  def handle_call(:lst, _from, nick_pid_map) do
    {:reply, Map.keys(nick_pid_map), nick_pid_map}
  end

  @impl true
  def init(_) do
    {:ok, Map.new()}
  end

end
