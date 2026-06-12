defmodule XPlane.Acf.AircraftTest do
  use ExUnit.Case, async: true

  alias XPlane.Acf.Schema

  @acf """
  I
  1100 Version
  ACF
  PROPERTIES_BEGIN
  P acf/_name Demo Plane
  P acf/_ICAO DEMO
  P acf/_author Tester
  P acf/_descrip A demo
  P acf/_manufacturer Acme
  P acf/_m_empty 1000.0
  P acf/_m_max 2000.0
  P acf/_is_glider 0
  P acf/_Mmo 0.500000
  P acf/_cgZ_fwd 3.000000
  P acf/_cgZ_aft 4.000000
  P acf/_cgY 0.300000
  P _wing/0/_Croot 5.000000
  P _wing/0/_Ctip 2.000000
  P _wing/0/_dihed_design 3.000000
  P _wing/0/_sweep_design 1.000000
  P _wing/0/_els 10
  P _wing/0/_var_retract 0
  P _wing/0/_afl_file_R0 root.afl
  P _wing/0/_afl_file_T0 tip.afl
  P _wing/2/_Croot 1.500000
  P _engn/0/_type 2
  P _prop/0/_num_blades 3
  P _prop/0/_prop_dir 1
  P _gear/0/_gear_type 1
  P _gear/0/_leg_len 2.500000
  P _cgpt/0/_name Pilot
  P _cgpt/0/_w_now 80.000000
  P _cgpt/0/_z_ref 3.500000
  P _cgpt/count 1
  P _lite/0/_lite_type 1
  P _lite/0/_rgb/0 1.000000
  P _lite/0/_rgb/1 0.500000
  P _lite/0/_rgb/2 0.000000
  P _obja/0/_v10_att_file_stl wheel.obj
  P _door/0/_type 1
  P _door/0/_ext_ang 45.000000
  PROPERTIES_END
  """

  setup do
    {:ok, doc} = XPlane.Acf.parse(@acf)
    %{doc: doc, acf: XPlane.Acf.aircraft(doc)}
  end

  test "top-level identity and mass scalars", %{acf: acf} do
    assert acf.version == 1100
    assert acf.name == "Demo Plane"
    assert acf.icao == "DEMO"
    assert acf.author == "Tester"
    assert acf.manufacturer == "Acme"
    assert acf.mass_empty == 1000.0
    assert acf.mass_max == 2000.0
    assert acf.max_mach == 0.5
    assert acf.glider == false
  end

  test "wings: sparse indices and geometry + airfoil files", %{acf: acf} do
    assert Enum.map(acf.wings, & &1.index) == [0, 2]
    w0 = hd(acf.wings)
    assert w0.root_chord == 5.0
    assert w0.tip_chord == 2.0
    assert w0.dihedral == 3.0
    assert w0.element_count == 10
    assert w0.retractable == false
    assert w0.airfoil_files == %{root_1: "root.afl", tip_1: "tip.afl"}
    assert w0.airfoils == %{}
  end

  test "engines, props, gear", %{acf: acf} do
    assert [%{type: 2}] = acf.engines
    assert [%{blade_count: 3, direction: 1}] = acf.props
    assert [%{type: 1, leg_length: 2.5}] = acf.gears
  end

  test "weight stations, lights, objects, doors", %{acf: acf} do
    assert [%{name: "Pilot", weight_now: 80.0, arm: 3.5}] = acf.weight_stations
    assert [%{file: "wheel.obj"}] = acf.objects
    assert [%{type: 1, extend_angle: 45.0}] = acf.doors

    assert [light] = acf.lights
    assert light.type == 1
    assert light.rgb == [1.0, 0.5, 0.0]
  end

  describe "semantic writeback (lossless)" do
    test "Schema.put for an aircraft scalar", %{doc: doc, acf: acf} do
      doc = Schema.put(doc, :aircraft, :icao, "DMO2")
      assert XPlane.Acf.aircraft(doc).icao == "DMO2"
      # original aircraft snapshot is unchanged
      assert acf.icao == "DEMO"
      assert XPlane.Acf.to_string(doc) =~ "P acf/_ICAO DMO2\n"
    end

    test "Schema.put for a component field", %{doc: doc} do
      doc = Schema.put(doc, :wing, 0, :root_chord, 6.25)

      assert XPlane.Acf.aircraft(doc) |> Map.fetch!(:wings) |> hd() |> Map.fetch!(:root_chord) ==
               6.25

      assert XPlane.Acf.to_string(doc) =~ "P _wing/0/_Croot 6.25\n"
    end
  end

  describe "CRLF files" do
    test "round-trips byte-exact and yields clean string values" do
      crlf = String.replace(@acf, "\n", "\r\n")
      {:ok, doc} = XPlane.Acf.parse(crlf)
      assert doc.eol == "\r\n"
      assert XPlane.Acf.to_string(doc) == crlf
      acf = XPlane.Acf.aircraft(doc)
      assert acf.icao == "DEMO"
      assert hd(acf.wings).airfoil_files == %{root_1: "root.afl", tip_1: "tip.afl"}
    end
  end
end
