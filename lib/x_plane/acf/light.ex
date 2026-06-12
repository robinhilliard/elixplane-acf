defmodule XPlane.Acf.Light do
  @moduledoc """
  A light (`_lite/<n>`): type, size and (when present) an `rgb` colour triple.
  """

  use XPlane.Acf.Component, kind: :light, prefix: "_lite", extra: [:rgb]

  alias XPlane.Acf.Array

  defp augment(doc, index, base) do
    rgb = Enum.map(0..2, &Array.get_float(doc, "_lite", index, "_rgb/#{&1}"))
    Map.put(base, :rgb, if(Enum.all?(rgb, &is_nil/1), do: nil, else: rgb))
  end
end
