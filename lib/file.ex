defmodule Workflow.File do
  defstruct [oid: nil, name: nil, content_type: nil]
  def from(data, attr_name) do
    %__MODULE__{
      oid: data[attr_name][:oid],
      name: data[attr_name][:name],
      content_type: data[attr_name][:content_type],
    }
  end

  defp fp(file) do
    case file do
      %{oid: oid} -> oid
      oid -> oid
    end
  end

  def store(%{filename: filename, content_type: content_type, data: data}) do
    oid = :crypto.hash(:sha256, data)
    |> Base.url_encode64

    file_dir = Application.fetch_env!(:workflow, :file_dir)
    filepath = Path.join(file_dir, fp(oid))
    File.mkdir_p!(Path.dirname(filepath))

    case File.write(filepath, data, [:write]) do
      :ok ->
        {:ok, %{
          oid: oid,
          name: filename,
          content_type: content_type
        }}
      {:error, error}
        -> {:error, error}
    end
  end

  def read!(file) do
    file_dir = Application.fetch_env!(:workflow, :file_dir)
    filepath = Path.join(file_dir, fp(file))
    File.read!(filepath)
  end

  def cast_file(changeset, field, opts \\ []) do
    optional = not Keyword.get(opts, :required, false)

    case Ecto.Changeset.get_change(changeset, field) do
      nil ->
        if optional do
          changeset
        else
            Ecto.Changeset.add_error(changeset, field, "missing file")
        end

      %Plug.Upload{} = upload ->
        content_type = upload.content_type
        name = upload.filename
        oid = File.stream!(upload.path, [], 2048)
        |> Enum.reduce(:crypto.hash_init(:sha256),fn(line, acc) -> :crypto.hash_update(acc, line) end )
        |> :crypto.hash_final
        |> Base.url_encode64

        # Copy the file
        file_dir = Application.fetch_env!(:workflow, :file_dir)
        filepath = Path.join(file_dir, fp(oid))
        File.mkdir_p!(Path.dirname(filepath))

        case File.cp(upload.path, filepath) do
          :ok ->
            changeset
            |> Ecto.Changeset.put_change(field, %{
              oid: oid,
              name: name,
              content_type: content_type
            })
          {:error, error} ->
            changeset
            |> Ecto.Changeset.add_error(field, error)
        end
    end
  end

end
