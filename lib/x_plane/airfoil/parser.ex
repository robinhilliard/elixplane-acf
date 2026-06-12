defmodule XPlane.Airfoil.Parser do
  @moduledoc """
  Parser for X-Plane `.afl` airfoil files.

  Two layouts occur in the wild, distinguished by the version line:

    * `900 version` - header (3 lines), then a single polar: a parameter line,
      an `alpha cl cd cm:` marker, and the swept data rows.
    * `1110 Version` - header (3 lines), a thickness and a camber/position
      line, ~14 `x y` shape control points, a table count, then that many
      polars (each a parameter line, an `alpha cl cd cm:` marker and data rows).

  Data rows mix spaces and tabs and use irregular alpha steps, so all lines are
  retained verbatim for a byte-exact round-trip (see `XPlane.Airfoil.Encoder`).
  The structured fields below are parsed best-effort by locating the
  `alpha cl cd cm:` markers; each marker's parameter line is the line directly
  above it, and its data rows run up to the next polar (or end of file).
  """

  alias XPlane.Airfoil
  alias XPlane.Airfoil.Polar

  @header_re ~r/^\s*alpha\s+cl\s+cd\s+cm/i

  @doc "Parse `.afl` contents. Options: `:source_path`."
  @spec parse_string(String.t(), keyword()) :: {:ok, Airfoil.t()} | {:error, term()}
  def parse_string(content, opts \\ []) when is_binary(content) do
    {lines, eol, trailing?} = XPlane.Text.split_lines(content)

    byte_order = lines |> Enum.at(0, "") |> String.trim()
    {version, version_label} = parse_version(Enum.at(lines, 1, ""))
    device_line = Enum.at(lines, 2, "")

    headers = header_indices(lines)
    polars = parse_polars(lines, headers)
    {thickness, shape_points} = parse_preamble(lines, headers)
    source_path = Keyword.get(opts, :source_path)

    airfoil = %Airfoil{
      byte_order: byte_order,
      version: version,
      version_label: version_label,
      device_line: device_line,
      thickness: thickness,
      shape_points: shape_points,
      polars: polars,
      lines: lines,
      eol: eol,
      trailing_newline: trailing?,
      source_path: source_path,
      name: source_path && Path.basename(source_path, ".afl")
    }

    {:ok, airfoil}
  end

  @doc "Read and parse a `.afl` file from disk."
  @spec parse_file(Path.t()) :: {:ok, Airfoil.t()} | {:error, term()}
  def parse_file(path) do
    case File.read(path) do
      {:ok, content} -> parse_string(content, source_path: path)
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_version(line) do
    case String.split(String.trim(line)) do
      [num, label | _] ->
        case Integer.parse(num) do
          {n, _} -> {n, label}
          :error -> {0, "Version"}
        end

      _ ->
        {0, "Version"}
    end
  end

  defp header_indices(lines) do
    lines
    |> Enum.with_index()
    |> Enum.flat_map(fn {line, i} -> if Regex.match?(@header_re, line), do: [i], else: [] end)
  end

  defp parse_polars(lines, headers) do
    total = length(lines)

    headers
    |> Enum.with_index()
    |> Enum.map(fn {h, i} ->
      params = if h >= 1, do: floats(Enum.at(lines, h - 1)), else: []

      last =
        case Enum.at(headers, i + 1) do
          nil -> total - 1
          next_h -> next_h - 2
        end

      points =
        if last >= h + 1 do
          lines |> Enum.slice((h + 1)..last) |> Enum.flat_map(&point_or_empty/1)
        else
          []
        end

      %Polar{reynolds: List.first(params), params: params, points: points}
    end)
  end

  # Everything between the device line and the first parameter line: thickness,
  # camber/position and the shape control points (1110+). Empty for 900 files.
  defp parse_preamble(_lines, []), do: {nil, nil}

  defp parse_preamble(lines, [first | _]) do
    first_params = first - 1
    preamble = Enum.slice(lines, 3, max(first_params - 3, 0))

    thickness =
      Enum.find_value(preamble, fn line ->
        case floats(line) do
          [t] when is_float(t) -> t
          _ -> nil
        end
      end)

    shape =
      Enum.flat_map(preamble, fn line ->
        case floats(line) do
          [x, y] when is_float(x) and is_float(y) -> [{x, y}]
          _ -> []
        end
      end)

    {thickness, if(shape == [], do: nil, else: shape)}
  end

  defp point_or_empty(line) do
    case floats(line) do
      [a, cl, cd, cm] when is_float(a) and is_float(cl) and is_float(cd) and is_float(cm) ->
        [{a, cl, cd, cm}]

      _ ->
        []
    end
  end

  defp floats(nil), do: []

  defp floats(line) do
    line
    |> String.split()
    |> Enum.map(fn token ->
      case Float.parse(token) do
        {f, _rest} -> f
        :error -> :nan
      end
    end)
  end
end
