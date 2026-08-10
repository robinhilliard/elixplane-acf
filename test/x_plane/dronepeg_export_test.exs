defmodule XPlane.DronepegExportTest do
  use ExUnit.Case, async: true

  @fixture_root Path.expand("../../../dronepeg/test/fixtures/dronepeg-export", __DIR__)
  @acf Path.join(@fixture_root, "dronepeg.acf")

  @tag :dronepeg_export
  test "parse dronepeg-export fixture when present" do
    if not File.exists?(@acf) do
      flunk("""
      fixture missing — run from dronepeg repo:
        node scripts/verify-xplane-export.mjs
      """)
    end

    aircraft =
      @acf
      |> XPlane.Acf.read!()
      |> XPlane.Acf.aircraft()
      |> XPlane.Acf.load_airfoils(base: @fixture_root)

    assert aircraft.name == "dronepeg"
    assert aircraft.icao == "DRPG"
    assert length(aircraft.wings) >= 1

    foil_names =
      aircraft.wings
      |> Enum.flat_map(fn w -> Map.values(w.airfoils) end)
      |> Enum.map(& &1.name)
      |> Enum.uniq()
      |> Enum.sort()

    assert "dronepeg-wing-root" in foil_names
    assert "dronepeg-0010" in foil_names
  end
end
