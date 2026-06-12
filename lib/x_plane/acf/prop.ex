defmodule XPlane.Acf.Prop do
  @moduledoc """
  A propeller/rotor (`_prop/<n>`), paired by index with an `XPlane.Acf.Engine`.
  """

  use XPlane.Acf.Component, kind: :prop, prefix: "_prop"
end
