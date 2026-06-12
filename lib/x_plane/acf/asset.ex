defmodule XPlane.Acf.Asset do
  @moduledoc """
  External files referenced by property values in a `.acf`.

  Three property families carry rewritable file references:

    * `:airfoil` - `_wing/<n>/_afl_file_{R0,R1,T0,T1}` (`.afl`)
    * `:object`  - `_obja/<n>/_v10_att_file_stl` (`.obj`)
    * `:sound`   - `acf/_ann_wav_file/<n>` (`.wav` annunciator sounds)

  Paths are stored relative to the aircraft's folder (the directory containing
  the `.acf`). This module enumerates references, checks which resolve on disk,
  and rewrites them losslessly (only the touched property lines change).

  Note: X-Plane also loads many assets *by convention* (the cockpit object,
  liveries, FMOD `sounds/`, `*.vrconfig.txt`, Lua scripts) that are not named
  in properties; those are out of scope here.
  """

  alias XPlane.Acf.Document

  @patterns [
    {:airfoil, ~r{^_wing/\d+/_afl_file_(?:R0|R1|T0|T1)$}},
    {:object, ~r{^_obja/\d+/_v10_att_file_stl$}},
    {:sound, ~r{^acf/_ann_wav_file/\d+$}}
  ]

  defstruct [:key, :kind, :path]

  @type kind :: :airfoil | :object | :sound
  @type t :: %__MODULE__{key: String.t(), kind: kind(), path: String.t()}

  @doc "List every external file reference (with non-empty path) in the document."
  @spec list(Document.t()) :: [t()]
  def list(%Document{} = doc) do
    for key <- Document.keys(doc),
        {kind, re} <- @patterns,
        Regex.match?(re, key),
        path = trimmed(Document.get(doc, key)),
        path != nil do
      %__MODULE__{key: key, kind: kind, path: path}
    end
  end

  @doc "List references of a single kind."
  @spec list(Document.t(), kind()) :: [t()]
  def list(%Document{} = doc, kind), do: doc |> list() |> Enum.filter(&(&1.kind == kind))

  @doc "Unique referenced paths."
  @spec paths(Document.t()) :: [String.t()]
  def paths(%Document{} = doc), do: doc |> list() |> Enum.map(& &1.path) |> Enum.uniq()

  @doc "The aircraft folder (directory of `source_path`), or `nil` if unknown."
  @spec base_dir(Document.t()) :: String.t() | nil
  def base_dir(%Document{source_path: nil}), do: nil
  def base_dir(%Document{source_path: path}), do: Path.dirname(path)

  @doc "Whether a relative `path` resolves to an existing file under `base`."
  @spec exists?(String.t() | nil, String.t()) :: boolean()
  def exists?(base, path) when is_binary(base), do: File.exists?(Path.join(base, path))
  def exists?(nil, _path), do: false

  @doc """
  References whose files do not exist under `base` (defaults to `base_dir/1`).
  With no resolvable base, all references are considered missing.
  """
  @spec missing(Document.t(), String.t() | nil) :: [t()]
  def missing(%Document{} = doc, base \\ nil) do
    base = base || base_dir(doc)
    doc |> list() |> Enum.reject(&exists?(base, &1.path))
  end

  @doc """
  Rewrite asset paths losslessly.

  Pass a function `(asset -> new_path | nil)` (return `nil` to leave a
  reference unchanged) or a `%{old_path => new_path}` map.

      XPlane.Acf.Asset.rewrite(doc, fn a ->
        if a.kind == :airfoil, do: Path.join("airfoils", Path.basename(a.path))
      end)
  """
  @spec rewrite(Document.t(), (t() -> String.t() | nil) | map()) :: Document.t()
  def rewrite(%Document{} = doc, map) when is_map(map) do
    rewrite(doc, fn asset -> Map.get(map, asset.path) end)
  end

  def rewrite(%Document{} = doc, fun) when is_function(fun, 1) do
    Enum.reduce(list(doc), doc, fn asset, doc ->
      case fun.(asset) do
        nil -> doc
        unchanged when unchanged == asset.path -> doc
        new_path -> Document.put_raw(doc, asset.key, new_path)
      end
    end)
  end

  defp trimmed(nil), do: nil

  defp trimmed(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
