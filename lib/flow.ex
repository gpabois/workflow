defmodule Workflow.Flow do
    @callback get_flow() :: term

    defstruct name: nil, nodes: %{}

    def get_flow(name) do
        Workflow.Registry.get(name)
    end

    def get_flow_node(flow, node_name) do
        flow.nodes[node_name]
    end
end
