defmodule Workflow.Registry do
    use GenServer

    def start_link(flows \\ []) do
        GenServer.start_link(__MODULE__, flows, name: __MODULE__)
    end

    @impl true
    def init(flows \\ []) do
      {:ok, flows}
    end

    @impl true
    def handle_cast({:register, name, flow}, flows) do
        {:noreply, flows |> Keyword.put(name |> String.to_atom, flow)}
    end
    
    def handle_call(msg, _from, flows) do
        case msg do
            {:get, name} ->
                 {:reply, Keyword.get(flows, name |> String.to_atom), flows}
            :reset -> 
                {:noreply, :ok, []}
        end
    end

    def reset() do
        GenServer.call(__MODULE__, :reset)
    end

    def register(flow, name) do
        GenServer.cast(__MODULE__, {:register, flow, name})
    end

    def get(name) do
        GenServer.call(__MODULE__, {:get, name})
    end
end