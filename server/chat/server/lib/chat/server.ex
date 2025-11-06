defmodule Chat.Server do
  use GenServer

  @impl true
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: {:global, __MODULE__})
  end


end
