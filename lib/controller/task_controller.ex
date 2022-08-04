defmodule Workflow.TaskController do

    defmacro __using__(_opts \\ []) do
        quote do
            alias Workflow.{Process, Task, Flow}

             def prepare(conn, %{"task_id" => task_id} = args) do
                task = Task.get(task_id)
                process = Process.get(task.process_id)
                flow = Process.get_flow(process)
                node = Task.get_flow_node(task)

                def_ctx_extractor = fn ctx -> [] end

                cond do
                    node.controller != nil ->
                        {controller, actions} = case node.controller do
                            {controller, actions} -> {controller, actions}
                            controller -> {controller, []}
                        end
                        apply(controller, Keyword.get(actions, :prepare, :prepare), [
                            conn,
                            args
                            |> Map.put("node", node)
                            |> Map.put("task", task)
                            |> Map.put("flow", flow)
                            |> Map.put("process", process)
                        ])
                    true -> raise "You have to set either view or controller for the UserAction"
                end
            end

            def execute(conn, %{"task_id" => task_id, "user_action" => user_action_params} = args) do
                task = Task.get(task_id)
                process = Process.get(task.process_id)
                node = Task.get_flow_node(task)

                def_ctx_extractor = fn ctx -> [] end

                cond do
                    node.controller != nil ->
                        {controller, actions} = case node.controller do
                            {controller, actions} -> {controller, actions}
                            controller -> {controller, []}
                        end

                        apply(controller, Keyword.get(actions, :execute, :execute), [
                            conn,
                            args
                            |> Map.put("task", task)
                            |> Map.put("process", process)
                            |> Map.put("node", node)
                        ])
                    true -> raise "You have to set either controller for the UserAction"
                end
            end
        end
    end
end
