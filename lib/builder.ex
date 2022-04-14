defmodule Workflow.Builder do
    alias Workflow.Flow.Nodes.{Start, UserAction, Job, Condition, End}

    def begin(next, opts) do
        %{}
        |> start(next)
    end

    def start(flow, fields, next, opts \\ []) do
        flow
        |> Map.put("start", %Start{fields: fields, view: Keyword.get(opts, :view, nil), next: next})
    end

    def nend(flow) do
        flow
        |> Map.put("end", %End{})
    end

    def user_action(flow, id, fields, assign_user, next, opts \\ []) do
        flow
        |> Map.put(id, %UserAction {
                fields: fields,
                view: Keyword.get(opts, :view, nil),
                assign_user: assign_user, 
                next: next
            }
        )
    end

    def job(flow, id, work, next) do
        flow
        |> Map.put(id, %Job{work: work, next: next})
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
