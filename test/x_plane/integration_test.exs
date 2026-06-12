defmodule XPlane.IntegrationTest do
  use ExUnit.Case, async: true

  @acf """
  I
  1100 Version
  ACF
  PROPERTIES_BEGIN
  P acf/_name Loader Demo
  P _wing/0/_Croot 5.000000
  P _wing/0/_afl_file_R0 mini.afl
  P _wing/0/_afl_file_T0 mini.afl
  P _wing/2/_Croot 1.500000
  P _wing/2/_afl_file_R0 missing.afl
  PROPERTIES_END
  """

  @afl """
  I
  1110 Version
  1234 device type code XA EA
  0.090000
  0.750000
  -0.25000 0.00000
  0.75000 0.00000
  1
  0.28000 0.5 0.1
  alpha cl cd cm:
  -180.0 0.225 0.047 0.056
  0.0 0.500 0.010 -0.040
  180.0 0.225 0.047 0.056
  """

  setup do
    root = Path.join(System.tmp_dir!(), "acf_int_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "airfoils"))
    File.write!(Path.join(root, "plane.acf"), @acf)
    File.write!(Path.join([root, "airfoils", "mini.afl"]), @afl)
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root, acf_path: Path.join(root, "plane.acf")}
  end

  test "load_airfoils resolves via airfoils/ subdir, dedupes, and skips missing", %{
    acf_path: acf_path
  } do
    aircraft =
      acf_path |> XPlane.Acf.read!() |> XPlane.Acf.aircraft() |> XPlane.Acf.load_airfoils()

    [w0, w2] = aircraft.wings

    # wing 0 references mini.afl in two slots; both resolve to one shared struct
    assert %XPlane.Airfoil{version: 1110, name: "mini"} = w0.airfoils[:root_1]
    assert w0.airfoils[:tip_1] == w0.airfoils[:root_1]
    assert map_size(w0.airfoils) == 2
    assert hd(w0.airfoils[:root_1].polars).reynolds == 0.28

    # wing 2 references a non-existent file -> slot omitted, no crash
    assert w2.airfoils == %{}
  end

  test "a loaded airfoil writes back byte-exact", %{root: root, acf_path: acf_path} do
    aircraft =
      acf_path |> XPlane.Acf.read!() |> XPlane.Acf.aircraft() |> XPlane.Acf.load_airfoils()

    foil = hd(aircraft.wings).airfoils[:root_1]
    original = File.read!(Path.join([root, "airfoils", "mini.afl"]))
    assert XPlane.Airfoil.to_string(foil) == original
  end

  test "load_airfoils also accepts a document directly", %{acf_path: acf_path} do
    aircraft = acf_path |> XPlane.Acf.read!() |> XPlane.Acf.load_airfoils()
    assert %XPlane.Airfoil{} = hd(aircraft.wings).airfoils[:root_1]
  end
end
