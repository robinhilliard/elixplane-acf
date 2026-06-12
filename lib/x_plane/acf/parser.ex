defmodule XPlane.Acf.Parser do
  @moduledoc """
  Parser for X-Plane text `.acf` files (X-Plane 10/11 era).

  The file layout is:

      I                 # byte-order char (I = PC, A = Apple); irrelevant for text
      1100 Version      # version int + label; XP10 uses lowercase "version"
      ACF               # class tag
                        # blank line
      PROPERTIES_BEGIN
      P <name> <value>  # ... thousands of properties ...
      PROPERTIES_END
      PANEL_2D_BEGIN ... PANEL_2D_END
      PANEL_3D_BEGIN ... PANEL_3D_END

  Only `P ` lines *within* the `PROPERTIES` block are parsed as properties;
  everything else is kept verbatim for a lossless round-trip. The version
  token is matched case-insensitively (`Version`/`version`).
  """

  alias XPlane.Acf.Document

  @doc """
  Parse `.acf` file contents. Options: `:source_path`.
  """
  @spec parse_string(String.t(), keyword()) :: {:ok, Document.t()} | {:error, term()}
  def parse_string(content, opts \\ []) when is_binary(content) do
    {lines, eol, trailing?} = XPlane.Text.split_lines(content)

    {byte_order, version, version_label} = parse_header_version(lines)
    class = find_class(lines)

    if class == "ACF" do
      {pbegin, pend} = find_properties(lines)
      {props, order, line_names} = parse_props(lines, pbegin, pend)

      doc = %Document{
        byte_order: byte_order,
        version: version,
        version_label: version_label,
        class: class,
        lines: lines,
        props: props,
        order: order,
        line_names: line_names,
        properties_begin: pbegin,
        properties_end: pend,
        eol: eol,
        trailing_newline: trailing?,
        source_path: Keyword.get(opts, :source_path)
      }

      {:ok, doc}
    else
      {:error, :not_an_acf_file}
    end
  end

  @doc "Read and parse a `.acf` file from disk."
  @spec parse_file(Path.t()) :: {:ok, Document.t()} | {:error, term()}
  def parse_file(path) do
    case File.read(path) do
      {:ok, content} -> parse_string(content, source_path: path)
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_header_version(lines) do
    first3 = Enum.take(lines, 3)
    byte_order = first3 |> Enum.at(0, "") |> String.trim()

    {version, label} =
      Enum.find_value(first3, {0, "Version"}, fn line ->
        case String.split(String.trim(line)) do
          [num, label | _] ->
            if String.downcase(label) == "version" do
              case Integer.parse(num) do
                {n, _} -> {n, label}
                :error -> nil
              end
            end

          _ ->
            nil
        end
      end)

    {byte_order, version, label}
  end

  defp find_class(lines) do
    lines
    |> Enum.take(3)
    |> Enum.find_value(nil, fn line ->
      if String.trim(line) == "ACF", do: "ACF"
    end)
  end

  defp find_properties(lines) do
    indexed = Enum.with_index(lines)
    pbegin = find_marker(indexed, "PROPERTIES_BEGIN")
    pend = find_marker(indexed, "PROPERTIES_END")
    {pbegin, pend}
  end

  defp find_marker(indexed, marker) do
    Enum.find_value(indexed, nil, fn {line, i} ->
      if String.trim(line) == marker, do: i
    end)
  end

  defp parse_props(_lines, nil, _pend), do: {%{}, [], %{}}

  defp parse_props(lines, pbegin, pend) do
    {props, order, names} =
      lines
      |> Enum.with_index()
      |> Enum.reduce({%{}, [], %{}}, fn {line, i}, {props, order, names} = acc ->
        if i > pbegin and (is_nil(pend) or i < pend) and String.starts_with?(line, "P ") do
          {name, value} = parse_prop_line(line)
          {Map.put_new(props, name, value), [name | order], Map.put(names, i, name)}
        else
          acc
        end
      end)

    {props, Enum.reverse(order), names}
  end

  defp parse_prop_line("P " <> rest) do
    case :binary.split(rest, " ") do
      [name, value] -> {name, value}
      [name] -> {name, ""}
    end
  end
end
