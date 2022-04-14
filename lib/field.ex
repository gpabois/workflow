defmodule Workflow.Field do
    defstruct id: nil, type: nil, input_type: nil, label: nil, values: nil, values_fn: nil, required: false

    def ecto_types(fields) do
        fields
        |> Enum.map(fields, fn field -> {field.id, field.type} end)
        |> Map.new
    end

    def ecto_required_fields(fields) do
        fields
        |> Enum.filter(fields, fn field -> field.required end)
        |> Enum.map(fields, fn field -> field.id end)
    end

    def ecto_fields(fields) do
        fields
        |> Enum.map(fn field -> field.id end)
    end

    def select(id, type, opts) do
        %__MODULE__{
            type: type,
            input_type: :select,
            id: id, 
            label: Keyword.get(opts, :label, id),
            required: Keyword.get(opts, :required, false),
            values: Keyword.get(opts, :values, []),
            values_fn: Keyword.get(opts, :values_fn, fn -> [] end)
        }
    end

    def boolean(id, opts) do
        %__MODULE__{
            type: :boolean,
            input_type: Keyword.get(opts, :input_type, :checkbox),
            id: id, 
            label: Keyword.get(opts, :label, id),
            required: Keyword.get(opts, :required, false),
            values: Keyword.get(opts, :values, []),
            values_fn: Keyword.get(opts, :values_fn, fn -> [] end)
        }
    end

    def file(id, type, opts) do
        %__MODULE__{
            type:       type,
            input_type: :file,
            id:         id, 
            label:      Keyword.get(opts, :label, id),
            required:   Keyword.get(opts, :required, false),
            values:     Keyword.get(opts, :values, []),
            values_fn:  Keyword.get(opts, :values_fn, fn -> [] end)
        }
    end

    def text(id, type, opts) do
        %__MODULE__{
            type: type,
            input_type: :text,
            id: id, 
            label: Keyword.get(opts, :label, id),
            required: Keyword.get(opts, :required, false),
            values: Keyword.get(opts, :values, []),
            values_fn: Keyword.get(opts, :values_fn, fn -> [] end)
        }
    end

    def values(field) do
        if field.values <> nil do
            field.values
        else
            field.values_fn.()
        end
    end
end