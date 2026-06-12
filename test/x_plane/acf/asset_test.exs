defmodule XPlane.Acf.AssetTest do
  use ExUnit.Case, async: true

  alias XPlane.Acf.Asset

  @acf """
  I
  1100 Version
  ACF
  PROPERTIES_BEGIN
  P _wing/0/_afl_file_R0 root.afl
  P _wing/0/_afl_file_T0 airfoils/tip.afl
  P _obja/0/_v10_att_file_stl objects/wheel.obj
  P acf/_ann_wav_file/0 sounds/alarm.wav
  P acf/_ann_wav_file/1
  PROPERTIES_END
  """

  setup do
    {:ok, doc} = XPlane.Acf.parse(@acf)
    %{doc: doc}
  end

  test "list enumerates non-empty references with their kind", %{doc: doc} do
    assets = Asset.list(doc)
    assert length(assets) == 4
    assert Enum.count(assets, &(&1.kind == :airfoil)) == 2
    assert Enum.count(assets, &(&1.kind == :object)) == 1
    assert Enum.count(assets, &(&1.kind == :sound)) == 1
    # the empty _ann_wav_file/1 is skipped
    refute Enum.any?(assets, &(&1.key == "acf/_ann_wav_file/1"))
  end

  test "paths and list/2 by kind", %{doc: doc} do
    assert Enum.sort(Asset.paths(doc)) ==
             Enum.sort(["root.afl", "airfoils/tip.afl", "objects/wheel.obj", "sounds/alarm.wav"])

    assert Asset.list(doc, :airfoil) |> Enum.map(& &1.path) |> Enum.sort() ==
             ["airfoils/tip.afl", "root.afl"]
  end

  test "rewrite with a function changes only matching references, losslessly", %{doc: doc} do
    doc =
      Asset.rewrite(doc, fn
        %{kind: :airfoil} = a -> Path.join("airfoils", Path.basename(a.path))
        _ -> nil
      end)

    out = XPlane.Acf.to_string(doc)
    assert out =~ "P _wing/0/_afl_file_R0 airfoils/root.afl\n"
    assert out =~ "P _wing/0/_afl_file_T0 airfoils/tip.afl\n"
    # object/sound untouched
    assert out =~ "P _obja/0/_v10_att_file_stl objects/wheel.obj\n"
  end

  test "rewrite with a map remaps by old path", %{doc: doc} do
    doc = Asset.rewrite(doc, %{"root.afl" => "NACA0009.afl"})
    out = XPlane.Acf.to_string(doc)
    assert out =~ "P _wing/0/_afl_file_R0 NACA0009.afl\n"
    assert out =~ "P _wing/0/_afl_file_T0 airfoils/tip.afl\n"
  end

  test "missing reports references whose files are absent under base_dir", %{doc: doc} do
    tmp = Path.join(System.tmp_dir!(), "acf_asset_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    File.write!(Path.join(tmp, "root.afl"), "present")
    on_exit(fn -> File.rm_rf!(tmp) end)

    doc = %{doc | source_path: Path.join(tmp, "plane.acf")}
    missing = doc |> Asset.missing() |> Enum.map(& &1.path)

    refute "root.afl" in missing
    assert "airfoils/tip.afl" in missing
    assert "objects/wheel.obj" in missing
  end
end
