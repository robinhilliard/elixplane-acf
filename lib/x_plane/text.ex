defmodule XPlane.Text do
  @moduledoc false

  # Shared line-splitting for the text-based X-Plane formats (.acf, .afl).
  #
  # X-Plane files appear with LF, CRLF and (for some old hand-edited airfoils)
  # bare-CR line endings. We detect the delimiter, split on it, and remember it
  # so the encoder can rejoin with the same delimiter. Splitting and rejoining
  # on the *same* delimiter is always byte-exact, and the resulting logical
  # lines never contain the line ending, so parsed string values stay clean.

  @doc """
  Split `content` into `{lines, eol, trailing_newline?}` where `eol` is the
  detected line ending and `trailing_newline?` indicates whether the content
  ended with one (in which case the final empty element is dropped).
  """
  @spec split_lines(String.t()) :: {[String.t()], String.t(), boolean()}
  def split_lines(content) when is_binary(content) do
    {parts, eol, trailing?} =
      cond do
        String.contains?(content, "\r\n") ->
          {String.split(content, "\r\n"), "\r\n", String.ends_with?(content, "\r\n")}

        String.contains?(content, "\r") and not String.contains?(content, "\n") ->
          {String.split(content, "\r"), "\r", String.ends_with?(content, "\r")}

        true ->
          {String.split(content, "\n"), "\n", String.ends_with?(content, "\n")}
      end

    lines = if trailing?, do: Enum.drop(parts, -1), else: parts
    {lines, eol, trailing?}
  end
end
