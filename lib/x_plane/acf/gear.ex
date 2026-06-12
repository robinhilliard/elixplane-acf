defmodule XPlane.Acf.Gear do
  @moduledoc """
  A landing-gear leg (`_gear/<n>`): position, leg/tire dimensions and behaviour.
  """

  use XPlane.Acf.Component, kind: :gear, prefix: "_gear"
end
