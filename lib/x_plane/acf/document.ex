defmodule XPlane.Acf.Document do
  @moduledoc """
  Lossless, in-memory representation of an X-Plane `.acf` file.

  The whole file is retained as `lines` (verbatim), and the `PROPERTIES_BEGIN`
  ... `PROPERTIES_END` block is indexed so individual `P <name> <value>`
  properties can be read and edited. Edits are tracked as `overrides`,
  `additions` and `deletions` rather than mutating `lines`, so that an
  unmodified document re-encodes byte-for-byte (see `XPlane.Acf.Encoder`).

  Non-property content (the header and the `PANEL_2D`/`PANEL_3D` sections,
  including comments and blank lines) is preserved untouched.
  """

  alias XPlane.Acf.Value

  defstruct byte_order: "I",
            version: 0,
            version_label: "Version",
            class: "ACF",
            lines: [],
            props: %{},
            order: [],
            line_names: %{},
            properties_begin: nil,
            properties_end: nil,
            eol: "\n",
            trailing_newline: true,
            overrides: %{},
            additions: [],
            deletions: MapSet.new(),
            source_path: nil

  @type t :: %__MODULE__{
          byte_order: String.t(),
          version: integer(),
          version_label: String.t(),
          class: String.t(),
          lines: [String.t()],
          props: %{optional(String.t()) => String.t()},
          order: [String.t()],
          line_names: %{optional(non_neg_integer()) => String.t()},
          properties_begin: non_neg_integer() | nil,
          properties_end: non_neg_integer() | nil,
          eol: String.t(),
          trailing_newline: boolean(),
          overrides: %{optional(String.t()) => String.t()},
          additions: [{String.t(), String.t()}],
          deletions: MapSet.t(),
          source_path: String.t() | nil
        }

  @doc """
  Return the raw string value of a property, or `nil` if absent/deleted.
  """
  @spec get(t(), String.t()) :: String.t() | nil
  def get(%__MODULE__{} = doc, name) do
    cond do
      MapSet.member?(doc.deletions, name) -> nil
      Map.has_key?(doc.overrides, name) -> Map.get(doc.overrides, name)
      Map.has_key?(doc.props, name) -> Map.get(doc.props, name)
      true -> addition_value(doc, name)
    end
  end

  @doc """
  Fetch a property value, returning `{:ok, value}` or `:error`.
  """
  @spec fetch(t(), String.t()) :: {:ok, String.t()} | :error
  def fetch(%__MODULE__{} = doc, name) do
    case get(doc, name) do
      nil -> :error
      value -> {:ok, value}
    end
  end

  @doc "Whether a property is present (and not deleted)."
  @spec has_key?(t(), String.t()) :: boolean()
  def has_key?(%__MODULE__{} = doc, name), do: get(doc, name) != nil

  @doc "Read a property as a float (`nil` if absent)."
  @spec get_float(t(), String.t()) :: float() | nil
  def get_float(doc, name), do: maybe(get(doc, name), &Value.to_float/1)

  @doc "Read a property as an integer (`nil` if absent)."
  @spec get_integer(t(), String.t()) :: integer() | nil
  def get_integer(doc, name), do: maybe(get(doc, name), &Value.to_integer/1)

  @doc "Read a property as a boolean (`nil` if absent)."
  @spec get_boolean(t(), String.t()) :: boolean() | nil
  def get_boolean(doc, name), do: maybe(get(doc, name), &Value.to_boolean/1)

  @doc """
  Set a property to a typed value (number/boolean/string), formatting it via
  `XPlane.Acf.Value.format/1`. Adds the property if it does not exist.
  """
  @spec put(t(), String.t(), number() | boolean() | String.t()) :: t()
  def put(%__MODULE__{} = doc, name, value), do: put_raw(doc, name, Value.format(value))

  @doc """
  Set a property to an exact raw string (no formatting).
  """
  @spec put_raw(t(), String.t(), String.t()) :: t()
  def put_raw(%__MODULE__{} = doc, name, raw) when is_binary(raw) do
    doc = %{doc | deletions: MapSet.delete(doc.deletions, name)}

    cond do
      Map.has_key?(doc.props, name) ->
        %{doc | overrides: Map.put(doc.overrides, name, raw)}

      List.keymember?(doc.additions, name, 0) ->
        %{doc | additions: List.keyreplace(doc.additions, name, 0, {name, raw})}

      true ->
        %{doc | additions: doc.additions ++ [{name, raw}]}
    end
  end

  @doc "Remove a property."
  @spec delete(t(), String.t()) :: t()
  def delete(%__MODULE__{} = doc, name) do
    %{
      doc
      | deletions: MapSet.put(doc.deletions, name),
        overrides: Map.delete(doc.overrides, name),
        additions: List.keydelete(doc.additions, name, 0)
    }
  end

  @doc "List all property names in document order (additions last)."
  @spec keys(t()) :: [String.t()]
  def keys(%__MODULE__{} = doc) do
    base = Enum.reject(doc.order, &MapSet.member?(doc.deletions, &1))

    adds =
      doc.additions |> Enum.map(&elem(&1, 0)) |> Enum.reject(&MapSet.member?(doc.deletions, &1))

    base ++ adds
  end

  @doc "Return all effective properties as a `name => raw value` map."
  @spec properties(t()) :: %{optional(String.t()) => String.t()}
  def properties(%__MODULE__{} = doc) do
    for name <- keys(doc), into: %{}, do: {name, get(doc, name)}
  end

  @doc "Number of effective properties."
  @spec count(t()) :: non_neg_integer()
  def count(%__MODULE__{} = doc), do: doc |> keys() |> length()

  defp addition_value(doc, name) do
    case List.keyfind(doc.additions, name, 0) do
      {^name, value} -> value
      nil -> nil
    end
  end

  defp maybe(nil, _fun), do: nil
  defp maybe(value, fun), do: fun.(value)
end
