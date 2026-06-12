defmodule XPlane.Airfoil do
  @moduledoc """
  Read and write X-Plane `.afl` airfoil files.

  An airfoil is the lift/drag/moment definition referenced by a wing in a
  `.acf` (see `XPlane.Acf.Wing`). Parsing preserves the whole file for a
  byte-exact round-trip while also exposing structured data:

      {:ok, foil} = XPlane.Airfoil.read("airfoils/clark-y_9.afl")
      foil.version                       #=> 1110
      length(foil.polars)                #=> 3
      hd(foil.polars).reynolds           #=> 0.28
      hd(foil.polars).points |> hd()     #=> {-180.0, 0.2255, 0.047, 0.05637}

  Editing at the whole-file level is lossless: parse, then `write/2` reproduces
  the source exactly unless you replace `lines`. Use `XPlane.Acf.load_airfoils/2`
  to resolve and attach airfoils to an aircraft's wings.
  """

  import Kernel, except: [to_string: 1]

  alias XPlane.Airfoil.{Encoder, Parser}

  defstruct [
    :byte_order,
    :version,
    :version_label,
    :device_line,
    :thickness,
    :shape_points,
    :polars,
    :lines,
    :eol,
    :trailing_newline,
    :source_path,
    :name
  ]

  @type t :: %__MODULE__{
          byte_order: String.t(),
          version: integer(),
          version_label: String.t(),
          device_line: String.t(),
          thickness: float() | nil,
          shape_points: [{float(), float()}] | nil,
          polars: [XPlane.Airfoil.Polar.t()],
          lines: [String.t()],
          eol: String.t(),
          trailing_newline: boolean(),
          source_path: String.t() | nil,
          name: String.t() | nil
        }

  @doc "Parse `.afl` contents from a string."
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  defdelegate parse(content), to: Parser, as: :parse_string

  @doc "Read and parse a `.afl` file from disk."
  @spec read(Path.t()) :: {:ok, t()} | {:error, term()}
  defdelegate read(path), to: Parser, as: :parse_file

  @doc "Read a `.afl` file, raising on error."
  @spec read!(Path.t()) :: t()
  def read!(path) do
    case read(path) do
      {:ok, airfoil} -> airfoil
      {:error, reason} -> raise "could not read #{inspect(path)}: #{inspect(reason)}"
    end
  end

  @doc "Encode an airfoil back to `.afl` text (binary)."
  @spec to_string(t()) :: String.t()
  defdelegate to_string(airfoil), to: Encoder

  @doc "Encode an airfoil back to `.afl` text (iodata)."
  @spec to_iodata(t()) :: iodata()
  defdelegate to_iodata(airfoil), to: Encoder

  @doc "Write an airfoil to disk."
  @spec write(t(), Path.t()) :: :ok | {:error, term()}
  def write(%__MODULE__{} = airfoil, path), do: File.write(path, Encoder.to_iodata(airfoil))

  @doc "Write an airfoil to disk, raising on error."
  @spec write!(t(), Path.t()) :: t()
  def write!(%__MODULE__{} = airfoil, path) do
    case write(airfoil, path) do
      :ok -> airfoil
      {:error, reason} -> raise "could not write #{inspect(path)}: #{inspect(reason)}"
    end
  end
end
