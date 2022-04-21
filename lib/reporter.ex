defmodule Workflow.Reporter do
    alias Workflow.{Task, Repo, Engine}

    def notify_process_termination(process, _opts \\ []) do
        for task <- Task.get_by_subprocess(process.id) do
            with {:ok, task} <- Repo.update Task.update_changeset(task, %{status: "subprocess_terminated"}) do
                Engine.schedule_task(task)
            end
        end
    end

    def notify_task_termination(_task) do
    end
end