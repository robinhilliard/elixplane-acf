defmodule XPlane.Acf.Wing do
  @moduledoc """
  A lifting surface (`_wing/<n>`): wings, stabilizers and other aero segments.

  X-Plane stores these in fixed, frequently sparse slots. Beyond the geometric
  scalars (`root_chord`, `tip_chord`, `dihedral`, ...) each wing references up
  to four airfoil files. `airfoil_files` is a map of the populated slots
  (`:root_1`, `:root_2`, `:tip_1`, `:tip_2`); `airfoils` is filled in by
  `XPlane.Acf.load_airfoils/2` with parsed `XPlane.Airfoil` structs.
  """

  use XPlane.Acf.Component, kind: :wing, prefix: "_wing", extra: [:airfoil_files, :airfoils]

  alias XPlane.Acf.Array

  @airfoil_slots [
    root_1: "_afl_file_R0",
    root_2: "_afl_file_R1",
    tip_1: "_afl_file_T0",
    tip_2: "_afl_file_T1"
  ]

  defp augment(doc, index, base) do
    Map.merge(base, %{airfoil_files: airfoil_files(doc, index), airfoils: %{}})
  end

  defp airfoil_files(doc, index) do
    Enum.reduce(@airfoil_slots, %{}, fn {slot, suffix}, acc ->
      case Array.get(doc, "_wing", index, suffix) do
        nil -> acc
        "" -> acc
        file -> Map.put(acc, slot, file)
      end
    end)
  end
end
