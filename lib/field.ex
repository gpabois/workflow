defmodule Workflow.Field do
    defstruct [
        id: nil,
        type: nil,
        input_type: nil,
        label: nil,
        values: nil,
        values_fn: nil,
        required: false,
        default: nil,
        internal: false,
        validations: []
    ]

    def id(field) do
        field.id
    end

    def default(field) do
        field.default
    end

    def data(fields) do
        for field <- fields, reduce: %{} do
            data -> Map.put(data, id(field), default(field))
        end
    end

    def is_form_field?(field) do
        !field.internal
    end

    def input_type(field) do
        field.input_type
    end

    def label(field) do
        field.label
    end

    def ecto_types(fields) do
        fields
        |> Enum.map(fn field -> {field.id, field.type} end)
        |> Map.new
    end

    def ecto_required_fields(fields) do
        fields
        |> Enum.filter(fn field -> field.required end)
        |> Enum.map(fn field -> field.id end)
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
            internal: Keyword.get(opts, :internal, false),
            default: Keyword.get(opts, :default, nil),
            required: Keyword.get(opts, :required, false),
            values: Keyword.get(opts, :values, nil),
            values_fn: Keyword.get(opts, :values_fn, fn -> [] end)
        }
    end

    def boolean(id, opts \\ []) do
        %__MODULE__{
            type: :boolean,
            input_type: Keyword.get(opts, :input_type, :checkbox),
            id: id,
            internal: Keyword.get(opts, :internal, false),
            default: Keyword.get(opts, :default, nil),
            label: Keyword.get(opts, :label, id),
            required: Keyword.get(opts, :required, false),
            values: Keyword.get(opts, :values, nil),
            values_fn: Keyword.get(opts, :values_fn, fn -> [true, false] end)
        }
    end

    def file(id, opts \\ []) do
        %__MODULE__{
            type:       :map,
            input_type: :file,
            id:         id,
            internal:   Keyword.get(opts, :internal, false),
            default:    Keyword.get(opts, :default, nil),
            label:      Keyword.get(opts, :label, id),
            required:   Keyword.get(opts, :required, false),
            values:     Keyword.get(opts, :values, nil),
            values_fn:  Keyword.get(opts, :values_fn, fn -> [] end),
            validations: [fn changeset, _ -> Workflow.File.cast_file(changeset, id, opts) end]
        }
    end

    def text(id, type, opts) do
        %__MODULE__{
            type: type,
            input_type: Keyword.get(opts, :input_type, :text),
            id: id,
            internal: Keyword.get(opts, :internal, false),
            default: Keyword.get(opts, :default, nil),
            label: Keyword.get(opts, :label, id),
            required: Keyword.get(opts, :required, false),
            values: Keyword.get(opts, :values, []),
            values_fn: Keyword.get(opts, :values_fn, fn -> [] end)
        }
    end

    def values(field) do
        if field.values != nil do
            field.values
        else
            field.values_fn.()
        end
    end
end
