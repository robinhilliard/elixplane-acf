defmodule XPlane.Acf do
  @moduledoc """
  Read, edit and write X-Plane 11 `.acf` aircraft files.

  `XPlane.Acf` is the entry point. It parses a `.acf` into an
  `XPlane.Acf.Document` that preserves the entire file, lets you read and
  change individual properties, and writes the result back with a byte-exact
  round-trip for anything you did not touch.

      {:ok, acf} = XPlane.Acf.read("Cessna_172SP.acf")
      XPlane.Acf.get(acf, "acf/_ICAO")          #=> "C172"
      XPlane.Acf.get_float(acf, "_engn/0/_max_thrust")

      acf
      |> XPlane.Acf.put("acf/_ICAO", "C175")
      |> XPlane.Acf.write!("Cessna_172SP_mod.acf")

  Properties are addressed by their raw, version-specific path
  (e.g. `"_wing/0/_chord"`). Higher-level helpers (a semantic aircraft model,
  asset references, airfoil loading) build on this core.
  """

  import Kernel, except: [to_string: 1]

  alias XPlane.Acf.{Document, Encoder, Parser}

  @type t :: Document.t()

  @doc "Parse `.acf` contents from a string."
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  defdelegate parse(content), to: Parser, as: :parse_string

  @doc "Read and parse a `.acf` file from disk."
  @spec read(Path.t()) :: {:ok, t()} | {:error, term()}
  defdelegate read(path), to: Parser, as: :parse_file

  @doc "Read a `.acf` file, raising on error."
  @spec read!(Path.t()) :: t()
  def read!(path) do
    case read(path) do
      {:ok, doc} -> doc
      {:error, reason} -> raise "could not read #{inspect(path)}: #{inspect(reason)}"
    end
  end

  @doc "Encode a document back to `.acf` text (binary)."
  @spec to_string(t()) :: String.t()
  defdelegate to_string(doc), to: Encoder

  @doc "Encode a document back to `.acf` text (iodata)."
  @spec to_iodata(t()) :: iodata()
  defdelegate to_iodata(doc), to: Encoder

  @doc "Write a document to disk."
  @spec write(t(), Path.t()) :: :ok | {:error, term()}
  def write(%Document{} = doc, path), do: File.write(path, Encoder.to_iodata(doc))

  @doc "Write a document to disk, raising on error."
  @spec write!(t(), Path.t()) :: t()
  def write!(%Document{} = doc, path) do
    case write(doc, path) do
      :ok -> doc
      {:error, reason} -> raise "could not write #{inspect(path)}: #{inspect(reason)}"
    end
  end

  @doc "The file format version (e.g. `1100` for X-Plane 11, `1004` for X-Plane 10)."
  @spec version(t()) :: integer()
  def version(%Document{version: version}), do: version

  @doc """
  Build the semantic `XPlane.Acf.Aircraft` model (wings, engines, gear, ...)
  from a document.
  """
  @spec aircraft(t()) :: XPlane.Acf.Aircraft.t()
  defdelegate aircraft(doc), to: XPlane.Acf.Aircraft, as: :from_document

  @doc """
  List external file references (airfoils, objects, sounds). See
  `XPlane.Acf.Asset`.
  """
  @spec assets(t()) :: [XPlane.Acf.Asset.t()]
  defdelegate assets(doc), to: XPlane.Acf.Asset, as: :list

  @doc """
  Resolve, parse and attach the `.afl` airfoils referenced by an aircraft's
  wings. Accepts a document or an `XPlane.Acf.Aircraft`. See
  `XPlane.Acf.AirfoilLoader` for options.
  """
  @spec load_airfoils(t() | XPlane.Acf.Aircraft.t(), keyword()) :: XPlane.Acf.Aircraft.t()
  def load_airfoils(acf_or_aircraft, opts \\ []),
    do: XPlane.Acf.AirfoilLoader.load(acf_or_aircraft, opts)

  defdelegate get(doc, name), to: Document
  defdelegate fetch(doc, name), to: Document
  defdelegate has_key?(doc, name), to: Document
  defdelegate get_float(doc, name), to: Document
  defdelegate get_integer(doc, name), to: Document
  defdelegate get_boolean(doc, name), to: Document
  defdelegate put(doc, name, value), to: Document
  defdelegate put_raw(doc, name, raw), to: Document
  defdelegate delete(doc, name), to: Document
  defdelegate keys(doc), to: Document
  defdelegate properties(doc), to: Document
  defdelegate count(doc), to: Document
end
