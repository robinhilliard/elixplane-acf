defmodule XPlane.Acf.Object do
  @moduledoc """
  An attached object (`_obja/<n>`): an external `.obj` model (`file`) bolted to
  a part of the aircraft.
  """

  use XPlane.Acf.Component, kind: :object, prefix: "_obja"
end
