defmodule Workflow.ProcessController do

    defmacro __using__(opts \\ []) do
        quote do
            alias Workflow.{Process, Task, Flow}

            def download(conn, %{"process_id" => process_id, "field" => field}) do
                process = Process.get(process_id)
                file = process.context[field |> String.to_existing_atom]
                content = Workflow.File.read!(file)

                conn
                |> put_resp_header("content-disposition", ~s(filename="#{file.name}"))
                |> put_resp_content_type(file.content_type)
                |> Plug.Conn.send_resp(200, content)
            end

            def index(conn, %{"flow_type" => flow_type} = args) do
                flow = Flow.get_flow(flow_type)
                cond do
                    flow.controller != nil ->
                        {controller, actions} = case flow.controler do
                            {controller, actions} -> {controller, actions}
                            controller -> {controller, []}
                        end

                        apply(controller, Keyword.get(actions, :index, :index), [
                            conn,
                            args
                        ])
                    true -> raise "You have to set either view or controller for the Process"
                end
            end

            def show(conn, %{"process_id" => process_id} = args) do
                process = Process.get(process_id)
                flow    = Flow.get_flow(process.flow_type)

                cond do
                    flow.controller != nil ->
                        {controller, actions} = case flow.controller do
                            {controller, actions} -> {controller, actions}
                            controller -> {controller, []}
                        end

                        apply(controller, Keyword.get(actions, :show, :show), [
                            conn,
                            args
                        ])

                    true -> raise "You have to set either view or controller for the Process"
                end
            end

            def delete(conn, %{"process_id" => process_id} = args) do
                process = Process.get(process_id)
                flow    = Flow.get_flow(process.flow_type)

                cond do
                    flow.controller != nil ->
                        {controller, actions} = case flow.controller do
                            {controller, actions} -> {controller, actions}
                            controller -> {controller, []}
                        end

                        apply(controller, Keyword.get(actions, :delete, :delete), [
                            conn,
                            args
                        ])

                    true -> raise "You have to set either view or controller for the Process"
                end
            end

            def new(conn, %{"flow_type" => flow_type} = params) do
                flow = Flow.get_flow(flow_type)
                node = Flow.get_flow_node(flow, "start")

                cond do
                    flow.controller != nil ->
                        {controller, actions} = case flow.controller do
                            {controller, actions} -> {controller, actions}
                            controller -> {controller, []}
                        end

                        apply(controller, Keyword.get(actions, :new, :new), [
                            conn,
                            params
                            |> Map.put("flow", flow)
                            |> Map.put("node", node)
                        ])

                    true -> raise "You have to set either view or controller for the Process"
                end
            end

            def create(conn, %{"flow_type" => flow_type, "initiate" => initiate_params} = params) do
                flow = Flow.get_flow(flow_type)
                node = Flow.get_flow_node(flow, "start")

                cond do
                    flow.controller != nil ->
                        {controller, actions} = case flow.controller do
                            {controller, actions} -> {controller, actions}
                            controller -> {controller, []}
                        end

                        apply(controller, Keyword.get(actions, :create, :create), [
                            conn,
                            params
                            |> Map.put("flow", flow)
                            |> Map.put("node", node)
                        ])

                    true -> raise "You have to set either view or controller for the Process"
                end
            end
        end
    end
end
