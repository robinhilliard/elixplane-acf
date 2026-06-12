defmodule XPlane.Acf.Array do
  @moduledoc """
  Helpers for the array-structured properties in a `.acf` file.

  Many domains are stored as flat, indexed property keys, e.g. wings:

      P _wing/0/_chord 5.5
      P _wing/0/_afl_file_R0 root.afl
      P _wing/8/_chord 1.2
      P _wing/count 56

  Indices are frequently **sparse** (a Cessna only uses a handful of the
  available wing slots) and a sibling `<prefix>/count` records the declared
  size. These helpers let the semantic layer enumerate populated indices and
  read/write fields by `(prefix, index, field)` without string juggling.
  """

  alias XPlane.Acf.Document

  @doc "Build the property key `<prefix>/<index>/<field>`."
  @spec key(String.t(), non_neg_integer(), String.t()) :: String.t()
  def key(prefix, index, field), do: "#{prefix}/#{index}/#{field}"

  @doc "Value of the declared `<prefix>/count`, or `nil` if not present."
  @spec count(Document.t(), String.t()) :: integer() | nil
  def count(doc, prefix), do: Document.get_integer(doc, "#{prefix}/count")

  @doc """
  Sorted list of populated indices for `prefix`, derived from the keys that
  actually exist (handles sparse arrays).
  """
  @spec indices(Document.t(), String.t()) :: [non_neg_integer()]
  def indices(doc, prefix) do
    p = prefix <> "/"

    doc
    |> Document.keys()
    |> Enum.reduce(MapSet.new(), fn k, acc ->
      with true <- String.starts_with?(k, p),
           rest = String.replace_prefix(k, p, ""),
           seg = rest |> String.split("/", parts: 2) |> hd(),
           {i, ""} <- Integer.parse(seg) do
        MapSet.put(acc, i)
      else
        _ -> acc
      end
    end)
    |> Enum.sort()
  end

  @doc """
  Effective size of `prefix`: the declared `count` if present, otherwise one
  past the highest populated index, otherwise `0`.
  """
  @spec size(Document.t(), String.t()) :: non_neg_integer()
  def size(doc, prefix) do
    case count(doc, prefix) do
      nil ->
        case indices(doc, prefix) do
          [] -> 0
          idx -> Enum.max(idx) + 1
        end

      n ->
        n
    end
  end

  @doc "Read `<prefix>/<index>/<field>` as a raw string (`nil` if absent)."
  @spec get(Document.t(), String.t(), non_neg_integer(), String.t()) :: String.t() | nil
  def get(doc, prefix, index, field), do: Document.get(doc, key(prefix, index, field))

  @doc "Read `<prefix>/<index>/<field>` as a float."
  @spec get_float(Document.t(), String.t(), non_neg_integer(), String.t()) :: float() | nil
  def get_float(doc, prefix, index, field), do: Document.get_float(doc, key(prefix, index, field))

  @doc "Read `<prefix>/<index>/<field>` as an integer."
  @spec get_integer(Document.t(), String.t(), non_neg_integer(), String.t()) :: integer() | nil
  def get_integer(doc, prefix, index, field),
    do: Document.get_integer(doc, key(prefix, index, field))

  @doc "Read `<prefix>/<index>/<field>` as a boolean."
  @spec get_boolean(Document.t(), String.t(), non_neg_integer(), String.t()) :: boolean() | nil
  def get_boolean(doc, prefix, index, field),
    do: Document.get_boolean(doc, key(prefix, index, field))

  @doc "Set `<prefix>/<index>/<field>` to a typed value."
  @spec put(Document.t(), String.t(), non_neg_integer(), String.t(), term()) :: Document.t()
  def put(doc, prefix, index, field, value),
    do: Document.put(doc, key(prefix, index, field), value)

  @doc """
  All fields for one index as a `field => raw value` map, where `field` is the
  remainder of the key after `<prefix>/<index>/` (may itself contain `/` for
  nested arrays).
  """
  @spec group(Document.t(), String.t(), non_neg_integer()) :: %{
          optional(String.t()) => String.t()
        }
  def group(doc, prefix, index) do
    p = "#{prefix}/#{index}/"

    for k <- Document.keys(doc), String.starts_with?(k, p), into: %{} do
      {String.replace_prefix(k, p, ""), Document.get(doc, k)}
    end
  end
end
