defmodule Chat.ServerSupervisor do
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, nil, name: {:global, __MODULE__})
  end

  def start_worker(_) do
    DynamicSupervisor.start_child(
      # Global supervisor Chat.ServerSupervisor
      {:global, __MODULE__},
      # Global child Chat.Server
      %{
        id: Chat.Server,
        start: {Chat.Server, :start_link, []}
      }
    )
  end

  @impl true
  @spec init(any()) ::
          {:ok,
           %{
             extra_arguments: list(),
             intensity: non_neg_integer(),
             max_children: :infinity | non_neg_integer(),
             period: pos_integer(),
             strategy: :one_for_one
           }}
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
