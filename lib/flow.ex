defmodule Workflow.Flow do
    @callback get_flow() :: term

    defstruct [
        name: nil,
        nodes: %{},
        struct: [],
        controller: nil,
        view: nil
    ]

    def data(flow) do
        Enum.reduce(flow.struct, %{}, fn {k, opts}, acc ->
            acc
            |> Map.put(k, Keyword.get(opts, :default, nil))
        end)
    end

    def types(flow) do
        Enum.reduce(flow.struct, %{}, fn {k, opts}, acc ->
            acc
            |> Map.put(k, Keyword.get(opts, :type, :string))
        end)
    end

    def types(flow) do
        Enum.reduce(flow.struct, %{}, fn {k, opts}, acc ->
            acc
            |> Map.put(k, Keyword.get(opts, :type, :string))
        end)
    end

    def required_types(flow) do
        Enum.filter(flow.struct, fn {_k, opts} -> Keyword.get(opts, :required, false) end)
        |> Enum.map(fn {k, _} -> k end)
    end

    def get_flow(name) do
        Workflow.Registry.get(name)
    end

    def get_flow_node(flow, node_name) do
        flow.nodes[node_name]
    end
end
