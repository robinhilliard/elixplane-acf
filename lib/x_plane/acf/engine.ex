defmodule XPlane.Acf.Engine do
  @moduledoc """
  A powerplant (`_engn/<n>`). `type` is X-Plane's engine-type enum
  (jet, recip, turboprop, ...).
  """

  use XPlane.Acf.Component, kind: :engine, prefix: "_engn"
end
