defmodule XPlane.AirfoilTest do
  use ExUnit.Case, async: true

  @afl_1110 """
  I
  1110 Version
  1234 device type code XA EA
  0.090000
  0.750000
  -0.25000 0.00000
  0.20000 0.50000
  0.75000 0.00000
  0.20000 -0.50000
  2
  0.28000 0.5 0.1
  alpha cl cd cm:
  -180.0 0.225 0.047 0.056
  0.0 0.500 0.010 -0.040
  180.0 0.225 0.047 0.056
  1.11000 0.6 0.2
  alpha cl cd cm:
  -180.0 0.225 0.047 0.056
  0.0 0.560 0.009 -0.043
  180.0 0.225 0.047 0.056
  """

  @afl_900 """
  I
  900 version
  1234 device type code
  9.00000 0.13000 0.75 0.5
  alpha cl cd cm:
  -180.0 -0.375 0.011 -0.076
  0.0 0.5 0.01 -0.04
  180.0 -0.375 0.011 -0.076
  """

  describe "1110 (modern)" do
    setup do
      {:ok, foil} = XPlane.Airfoil.parse(@afl_1110)
      %{foil: foil}
    end

    test "header, thickness and shape", %{foil: foil} do
      assert foil.version == 1110
      assert foil.version_label == "Version"
      assert foil.thickness == 0.09
      assert length(foil.shape_points) == 4
      assert hd(foil.shape_points) == {-0.25, 0.0}
    end

    test "polars and points", %{foil: foil} do
      assert length(foil.polars) == 2
      assert Enum.map(foil.polars, & &1.reynolds) == [0.28, 1.11]
      p0 = hd(foil.polars)
      assert length(p0.points) == 3
      assert hd(p0.points) == {-180.0, 0.225, 0.047, 0.056}
    end

    test "byte-exact round trip", %{foil: foil} do
      assert XPlane.Airfoil.to_string(foil) == @afl_1110
    end
  end

  describe "900 (legacy)" do
    test "single polar, no shape block" do
      {:ok, foil} = XPlane.Airfoil.parse(@afl_900)
      assert foil.version == 900
      assert foil.version_label == "version"
      assert foil.thickness == nil
      assert foil.shape_points == nil
      assert length(foil.polars) == 1
      assert hd(foil.polars).reynolds == 9.0
      assert length(hd(foil.polars).points) == 3
      assert XPlane.Airfoil.to_string(foil) == @afl_900
    end
  end

  describe "bare-CR line endings" do
    test "detected and round-tripped, structure still parsed" do
      cr = String.replace(@afl_1110, "\n", "\r")
      {:ok, foil} = XPlane.Airfoil.parse(cr)
      assert foil.eol == "\r"
      assert foil.version == 1110
      assert length(foil.polars) == 2
      assert XPlane.Airfoil.to_string(foil) == cr
    end
  end
end
