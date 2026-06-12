defmodule XPlane.Acf.WeightStation do
  @moduledoc """
  A weight/payload station (`_cgpt/<n>`): a named load with current/max weight
  and a longitudinal `arm` used for CG calculations.
  """

  use XPlane.Acf.Component, kind: :weight_station, prefix: "_cgpt"
end
