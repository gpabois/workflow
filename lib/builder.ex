defmodule Workflow.Builder do
    alias Workflow.Flow.Nodes.{Start, UserAction, Job, Condition, End}

    def begin(next) do
        %{}
        |> start(next)
    end

    def start(flow, next) do
        flow
        |> Map.put("start", %Start{next: next})
    end

    def nend(flow) do
        flow
        |> Map.put("end", %End{})
    end

    def user_action(flow, id, view_url_fn, assign_user_fn, next) do
        flow
        |> Map.put(id, %UserAction{view_url_fn: view_url_fn, assign_user_fn: assign_user_fn, next: next})
    end

    def job(flow, id, work_fn, next) do
        flow
        |> Map.put(id, %Job{work_fn: work_fn, next: next})
    end

    def condition(flow, id, predicate, if_node, else_node) do
        flow
        |> Map.put(id, %Condition{predicate: predicate, if_node: if_node, else_node: else_node})
    end

    def build(nodes, name) do
        nodes = nodes |> nend()

        %Workflow.Flow{
            name: name,
            nodes: nodes
        }
    end
end
