defmodule XPlane.Airfoil.Encoder do
  @moduledoc """
  Serialize an `XPlane.Airfoil` back to `.afl` text.

  All lines are retained verbatim by the parser, so encoding simply rejoins
  them with the detected line ending. An unmodified airfoil round-trips
  byte-for-byte.
  """

  import Kernel, except: [to_string: 1]

  alias XPlane.Airfoil

  @doc "Encode an airfoil as iodata."
  @spec to_iodata(Airfoil.t()) :: iodata()
  def to_iodata(%Airfoil{} = airfoil) do
    body = Enum.intersperse(airfoil.lines, airfoil.eol)
    if airfoil.trailing_newline, do: [body, airfoil.eol], else: body
  end

  @doc "Encode an airfoil as a binary string."
  @spec to_string(Airfoil.t()) :: String.t()
  def to_string(%Airfoil{} = airfoil), do: airfoil |> to_iodata() |> IO.iodata_to_binary()
end
