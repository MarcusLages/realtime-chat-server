defmodule Chat.Server do
  @moduledoc """
  Module used to create a globally registered Chat server.

  The state being passed is a nick_pid_map.
  @type nick_pid_map :: %{String.t() => pid()}

  A bidirectional map would have been more time efficient for search from
  pid to nick, but since I am not expecting many users, this is ok.

  Messages are sent to the mailbox of each process as {:msg, content}
  """
  require Logger

  use GenServer
  @name {:global, __MODULE__}
  @store Chat.Store

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

  def logout() do
    GenServer.cast(@name, {:logout, self()})
  end

end
