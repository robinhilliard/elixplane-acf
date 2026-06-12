defmodule XPlane.AcfTest do
  use ExUnit.Case, async: true

  doctest XPlane.Acf

  @fixture Path.join([__DIR__, "..", "fixtures", "mini_1100.acf"])

  describe "parsing" do
    test "reads the header" do
      acf = XPlane.Acf.read!(@fixture)
      assert acf.byte_order == "I"
      assert acf.version == 1100
      assert acf.version_label == "Version"
      assert acf.class == "ACF"
    end

    test "reads property values, typed" do
      acf = XPlane.Acf.read!(@fixture)
      assert XPlane.Acf.get(acf, "acf/_name") == "Test Plane"
      assert XPlane.Acf.get(acf, "acf/_ICAO") == "TEST"
      assert XPlane.Acf.get_float(acf, "acf/_Gpos") == 4.5
      assert XPlane.Acf.get_float(acf, "_engn/0/_max_thrust") == 1100.0
      assert XPlane.Acf.get_integer(acf, "_cgpt/count") == 1
      assert XPlane.Acf.get(acf, "_wing/0/_afl_file_R0") == "Clark-Y (root).afl"
      assert XPlane.Acf.get(acf, "does/not/exist") == nil
    end

    test "rejects non-ACF content" do
      assert {:error, :not_an_acf_file} = XPlane.Acf.parse("I\n1100 Version\nWED\n")
    end
  end

  describe "byte-exact round trip" do
    test "an unmodified document re-encodes identically (incl. panel sections)" do
      original = File.read!(@fixture)
      acf = XPlane.Acf.read!(@fixture)
      assert XPlane.Acf.to_string(acf) == original
    end
  end

  describe "editing" do
    setup do
      %{acf: XPlane.Acf.read!(@fixture), original: File.read!(@fixture)}
    end

    test "put changes only the targeted line", %{acf: acf, original: original} do
      out = acf |> XPlane.Acf.put("acf/_ICAO", "C172") |> XPlane.Acf.to_string()
      assert out =~ "P acf/_ICAO C172\n"
      refute out =~ "P acf/_ICAO TEST"
      # Reverting just that line reproduces the original byte-for-byte.
      assert String.replace(out, "P acf/_ICAO C172", "P acf/_ICAO TEST") == original
    end

    test "put with a typed value formats it", %{acf: acf} do
      out = acf |> XPlane.Acf.put("acf/_Gpos", 6.0) |> XPlane.Acf.to_string()
      assert out =~ "P acf/_Gpos 6.0\n"
    end

    test "new properties are inserted before PROPERTIES_END", %{acf: acf} do
      out = acf |> XPlane.Acf.put("acf/_newprop", 42) |> XPlane.Acf.to_string()
      assert out =~ "P acf/_newprop 42\nPROPERTIES_END"
    end

    test "delete removes a property", %{acf: acf} do
      acf = XPlane.Acf.delete(acf, "acf/_ICAO")
      assert XPlane.Acf.get(acf, "acf/_ICAO") == nil
      refute XPlane.Acf.to_string(acf) =~ "_ICAO"
    end

    test "edits survive a re-parse", %{acf: acf} do
      out = acf |> XPlane.Acf.put("acf/_ICAO", "C172") |> XPlane.Acf.to_string()
      {:ok, reparsed} = XPlane.Acf.parse(out)
      assert XPlane.Acf.get(reparsed, "acf/_ICAO") == "C172"
    end
  end
end
