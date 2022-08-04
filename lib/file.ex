defmodule Workflow.File do
  defstruct [oid: nil, name: nil, content_type: nil]

  def from(data, attr_name) do
    %__MODULE__{
      oid: data["#{attr_name}__oid"],
      name: data["#{attr_name}__name"],
      content_type: data["#{attr_name}__content_type"],
    }
  end

  defp fp(file) do
    case file do
      %__MODULE__{oid: oid} -> oid
      oid -> oid
    end
  end

  def read!(file) do
    file_dir = Application.fetch_env!(:workflow, :file_dir)
    filepath = Path.join(file_dir, fp(file))
    File.read!(filepath)
  end

  def cast_file(changeset, field, opts \\ []) do
    optional = Keyword.get(opts, :optional, false)
    case Ecto.Changeset.get_field(changeset, field) do
      nil ->
        if optional do
          changeset
        else
            Ecto.Changeset.add_error(changeset, field, "missing file")
        end

        %Plug.Upload{} = upload ->
        content_type = upload.content_type
        nom = upload.filename
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
            |> Ecto.Changeset.put_change(:"#{field}__oid", oid)
            |> Ecto.Changeset.put_change(:"#{field}__name", nom)
            |> Ecto.Changeset.put_change(:"#{field}__content_type", content_type)
          {:error, error} ->
            Ecto.Changeset.add_error(changeset, field, error)
        end
    end
  end

end
