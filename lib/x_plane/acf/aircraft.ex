defmodule XPlane.Acf.Aircraft do
  @moduledoc """
  The top-level semantic model of an aircraft, composed from a
  `XPlane.Acf.Document`.

  It exposes curated identity, mass/CG and performance scalars plus lists of
  the component structs (`wings`, `engines`, `props`, `gears`,
  `weight_stations`, `lights`, `objects`, `doors`). The originating `document`
  is retained so downstream helpers (assets, airfoil loading) and the lossless
  property API remain available:

      acf = XPlane.Acf.read!("Cessna_172SP.acf") |> XPlane.Acf.aircraft()
      acf.name                       #=> "Cessna 172SP"
      length(acf.wings)
      hd(acf.engines).type

  This is a read-oriented snapshot. To edit losslessly, change the underlying
  document (via `XPlane.Acf`/`XPlane.Acf.Array`/`XPlane.Acf.Schema.put/4`) and
  rebuild the model.
  """

  alias XPlane.Acf.{Door, Engine, Gear, Light, Object, Prop, Schema, WeightStation, Wing}

  @scalar_fields Schema.fields(:aircraft) |> Enum.map(&elem(&1, 0))

  defstruct [
              :version,
              :path,
              :document,
              :wings,
              :engines,
              :props,
              :gears,
              :weight_stations,
              :lights,
              :objects,
              :doors
            ] ++ @scalar_fields

  @type t :: %__MODULE__{}

  @doc "Build the semantic aircraft model from a parsed document."
  @spec from_document(XPlane.Acf.Document.t()) :: t()
  def from_document(doc) do
    scalars = Schema.read(doc, :aircraft)

    struct(
      __MODULE__,
      Map.merge(scalars, %{
        version: doc.version,
        path: doc.source_path,
        document: doc,
        wings: Wing.all(doc),
        engines: Engine.all(doc),
        props: Prop.all(doc),
        gears: Gear.all(doc),
        weight_stations: WeightStation.all(doc),
        lights: Light.all(doc),
        objects: Object.all(doc),
        doors: Door.all(doc)
      })
    )
  end
end
