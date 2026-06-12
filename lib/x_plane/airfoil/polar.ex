defmodule XPlane.Airfoil.Polar do
  @moduledoc """
  One polar table within an `.afl` airfoil: the lift/drag/moment curve for a
  single Reynolds number.

    * `reynolds` - the Reynolds number (first value of the table's parameter
      line; typically in millions, e.g. `1.11`)
    * `params` - the full parameter line as a list of floats (max-cl, alpha
      ranges, cm, ...); its meaning is version-specific
    * `points` - the swept curve as `{alpha, cl, cd, cm}` tuples, from roughly
      -180 deg to +180 deg
  """

  defstruct [:reynolds, :params, :points]

  @type point :: {float(), float(), float(), float()}
  @type t :: %__MODULE__{
          reynolds: float() | nil,
          params: [float()],
          points: [point()]
        }
end
