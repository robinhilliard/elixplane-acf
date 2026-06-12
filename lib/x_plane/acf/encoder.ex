defmodule XPlane.Acf.Encoder do
  @moduledoc """
  Serialize an `XPlane.Acf.Document` back to `.acf` text.

  Each original line is re-emitted verbatim unless it is a property line whose
  value was overridden (then reformatted) or deleted (then dropped). New
  properties are inserted immediately before `PROPERTIES_END`. As a result, an
  unmodified document encodes byte-for-byte identically to the source.
  """

  import Kernel, except: [to_string: 1]

  alias XPlane.Acf.Document

  @doc "Encode a document as iodata."
  @spec to_iodata(Document.t()) :: iodata()
  def to_iodata(%Document{} = doc) do
    out =
      doc.lines
      |> Enum.with_index()
      |> Enum.flat_map(fn {line, i} -> emit_line(doc, line, i) end)

    out =
      if is_nil(doc.properties_end) and doc.additions != [],
        do: out ++ emit_additions(doc),
        else: out

    body = Enum.intersperse(out, doc.eol)
    if doc.trailing_newline, do: [body, doc.eol], else: body
  end

  @doc "Encode a document as a binary string."
  @spec to_string(Document.t()) :: String.t()
  def to_string(%Document{} = doc), do: doc |> to_iodata() |> IO.iodata_to_binary()

  defp emit_line(doc, line, i) do
    name = Map.get(doc.line_names, i)

    cond do
      not is_nil(name) and MapSet.member?(doc.deletions, name) ->
        []

      not is_nil(name) and Map.has_key?(doc.overrides, name) ->
        ["P " <> name <> " " <> Map.fetch!(doc.overrides, name)]

      i == doc.properties_end ->
        emit_additions(doc) ++ [line]

      true ->
        [line]
    end
  end

  defp emit_additions(doc) do
    for {name, value} <- doc.additions,
        not MapSet.member?(doc.deletions, name),
        do: "P " <> name <> " " <> value
  end
end
