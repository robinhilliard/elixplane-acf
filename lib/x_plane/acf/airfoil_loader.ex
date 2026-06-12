defmodule XPlane.Acf.AirfoilLoader do
  @moduledoc """
  Resolve the `.afl` files referenced by an aircraft's wings, parse them, and
  attach the resulting `XPlane.Airfoil` structs to each `XPlane.Acf.Wing`.

  Airfoil references in a `.acf` are stored relative to the aircraft folder;
  Plane-Maker conventionally keeps the files in an `airfoils/` subdirectory but
  also supports paths relative to the `.acf` itself. Each distinct file is read
  and parsed only once and shared across the wings/slots that use it.
  """

  alias XPlane.Acf.{Aircraft, Document}
  alias XPlane.Airfoil

  @default_dirs ["airfoils", "."]

  @doc """
  Load airfoils for an `XPlane.Acf.Aircraft` (or build one from a
  `XPlane.Acf.Document` first) and return it with each wing's `:airfoils` map
  populated by slot (`:root_1`, `:root_2`, `:tip_1`, `:tip_2`).

  Options:

    * `:base` - aircraft folder to resolve against (defaults to the directory
      of the document's `source_path`)
    * `:airfoil_dirs` - candidate subdirectories to search, in order
      (defaults to `#{inspect(@default_dirs)}`)
  """
  @spec load(Aircraft.t() | Document.t(), keyword()) :: Aircraft.t()
  def load(input, opts \\ [])

  def load(%Document{} = doc, opts), do: doc |> Aircraft.from_document() |> load(opts)

  def load(%Aircraft{} = aircraft, opts) do
    base = Keyword.get(opts, :base) || (aircraft.path && Path.dirname(aircraft.path))
    dirs = Keyword.get(opts, :airfoil_dirs, @default_dirs)

    {wings, _cache} =
      Enum.map_reduce(aircraft.wings, %{}, fn wing, cache ->
        {airfoils, cache} = load_slots(wing.airfoil_files || %{}, base, dirs, cache)
        {%{wing | airfoils: airfoils}, cache}
      end)

    %{aircraft | wings: wings}
  end

  defp load_slots(files, base, dirs, cache) do
    Enum.reduce(files, {%{}, cache}, fn {slot, file}, {acc, cache} ->
      case load_one(file, base, dirs, cache) do
        {:ok, airfoil, cache} -> {Map.put(acc, slot, airfoil), cache}
        {:miss, cache} -> {acc, cache}
      end
    end)
  end

  defp load_one(_file, nil, _dirs, cache), do: {:miss, cache}

  defp load_one(file, base, dirs, cache) do
    case resolve(file, base, dirs) do
      nil ->
        {:miss, cache}

      path ->
        case cache do
          %{^path => airfoil} ->
            {:ok, airfoil, cache}

          _ ->
            case Airfoil.read(path) do
              {:ok, airfoil} -> {:ok, airfoil, Map.put(cache, path, airfoil)}
              {:error, _reason} -> {:miss, cache}
            end
        end
    end
  end

  defp resolve(file, base, dirs) do
    dirs
    |> Enum.map(fn dir -> base |> Path.join(dir) |> Path.join(file) |> Path.expand() end)
    |> Enum.find(&File.exists?/1)
  end
end
