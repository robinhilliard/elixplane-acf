defmodule XPlane.Acf.ArrayTest do
  use ExUnit.Case, async: true

  alias XPlane.Acf.Array

  @acf """
  I
  1100 Version
  ACF
  PROPERTIES_BEGIN
  P _wing/0/_chord 5.500000
  P _wing/0/_afl_file_R0 root.afl
  P _wing/8/_chord 1.200000
  P _wing/9/_chord 1.000000
  P _wing/count 56
  P _engn/0/_max_thrust 1100.0
  PROPERTIES_END
  """

  setup do
    {:ok, doc} = XPlane.Acf.parse(@acf)
    %{doc: doc}
  end

  test "indices are derived from populated keys and sorted (sparse)", %{doc: doc} do
    assert Array.indices(doc, "_wing") == [0, 8, 9]
    assert Array.indices(doc, "_engn") == [0]
    assert Array.indices(doc, "_nope") == []
  end

  test "count reads the declared <prefix>/count", %{doc: doc} do
    assert Array.count(doc, "_wing") == 56
    assert Array.count(doc, "_engn") == nil
  end

  test "size prefers count, else max index + 1", %{doc: doc} do
    assert Array.size(doc, "_wing") == 56
    assert Array.size(doc, "_engn") == 1
    assert Array.size(doc, "_nope") == 0
  end

  test "typed field access", %{doc: doc} do
    assert Array.get_float(doc, "_wing", 0, "_chord") == 5.5
    assert Array.get(doc, "_wing", 0, "_afl_file_R0") == "root.afl"
    assert Array.get(doc, "_wing", 8, "_chord") == "1.200000"
    assert Array.get(doc, "_wing", 7, "_chord") == nil
  end

  test "put writes by (prefix, index, field)", %{doc: doc} do
    doc = Array.put(doc, "_wing", 8, "_chord", 2.5)
    assert Array.get_float(doc, "_wing", 8, "_chord") == 2.5
    assert XPlane.Acf.to_string(doc) =~ "P _wing/8/_chord 2.5\n"
  end

  test "group returns all fields for an index", %{doc: doc} do
    assert Array.group(doc, "_wing", 0) == %{
             "_chord" => "5.500000",
             "_afl_file_R0" => "root.afl"
           }
  end
end
