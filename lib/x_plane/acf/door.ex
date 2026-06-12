defmodule XPlane.Acf.Door do
  @moduledoc """
  A door/canopy/hatch (`_door/<n>`): type and open/closed angles.
  """

  use XPlane.Acf.Component, kind: :door, prefix: "_door"
end
