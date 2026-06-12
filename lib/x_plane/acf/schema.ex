defmodule XPlane.Acf.Schema do
  @moduledoc """
  Declarative mapping from semantic struct fields to `.acf` property keys.

  Each entry is `{field, key_or_suffix, type}` where `type` is one of
  `:string | :float | :integer | :boolean`. Top-level `:aircraft` fields use a
  full property key (e.g. `"acf/_ICAO"`); component kinds (`:wing`, `:engine`,
  ...) use the per-index *suffix* (e.g. `"_Croot"`), combined with the group
  prefix and index by `XPlane.Acf.Array`.

  The same field is read across X-Plane 10 (`1004`) and 11 (`1100`) files;
  fields that only exist in one version simply read back as `nil` for the
  other, so a single table serves both. The curated field names cover the most
  useful, human-meaningful properties - the full set remains accessible via the
  generic `XPlane.Acf`/`XPlane.Acf.Array` property API.
  """

  alias XPlane.Acf.{Array, Document}

  @aircraft [
    {:name, "acf/_name", :string},
    {:icao, "acf/_ICAO", :string},
    {:tail_number, "acf/_tailnum", :string},
    {:callsign, "acf/_callsign", :string},
    {:author, "acf/_author", :string},
    {:studio, "acf/_studio", :string},
    {:description, "acf/_descrip", :string},
    {:manufacturer, "acf/_manufacturer", :string},
    {:mass_empty, "acf/_m_empty", :float},
    {:mass_max, "acf/_m_max", :float},
    {:mass_displaced, "acf/_m_displaced", :float},
    {:cg_z_fwd, "acf/_cgZ_fwd", :float},
    {:cg_z_aft, "acf/_cgZ_aft", :float},
    {:cg_y, "acf/_cgY", :float},
    {:max_mach, "acf/_Mmo", :float},
    {:glider, "acf/_is_glider", :boolean}
  ]

  @wing [
    {:root_chord, "_Croot", :float},
    {:tip_chord, "_Ctip", :float},
    {:semi_length, "_semilen_SEG", :float},
    {:semi_length_joined, "_semilen_JND", :float},
    {:element_count, "_els", :integer},
    {:dihedral, "_dihed_design", :float},
    {:sweep, "_sweep_design", :float},
    {:incidence, "_incid_chrd_inc", :float},
    {:mirrored, "_is_right_mult", :boolean},
    {:retractable, "_var_retract", :boolean},
    {:variable_sweep, "_var_sweep", :boolean},
    {:variable_incidence, "_var_incid", :boolean},
    {:variable_dihedral, "_var_dihed", :boolean}
  ]

  @engine [
    {:type, "_type", :integer},
    {:mass, "_engn_mass", :float},
    {:moment_of_inertia, "_engn_mi_rpm", :float},
    {:clutched, "_engn_clutch_EQ", :boolean},
    {:freewheels, "_engn_freewheels", :boolean}
  ]

  @prop [
    {:type, "_prop_type", :integer},
    {:blade_count, "_num_blades", :integer},
    {:direction, "_prop_dir", :integer},
    {:gear_ratio, "_prop_gear_rat", :float},
    {:max_pitch, "_max_pitch", :float},
    {:min_pitch, "_min_pitch", :float},
    {:design_rpm, "_des_rpm_prp", :float},
    {:design_speed, "_des_kts_acf", :float},
    {:ducted, "_prop_ducted", :boolean}
  ]

  @gear [
    {:type, "_gear_type", :integer},
    {:x, "_gear_x", :float},
    {:y, "_gear_y", :float},
    {:z, "_gear_z", :float},
    {:leg_length, "_leg_len", :float},
    {:tire_radius, "_tire_radius", :float},
    {:tire_width, "_tire_swidth", :float},
    {:retractable, "_gear_can_retract", :boolean},
    {:has_brakes, "_gear_brakes", :boolean},
    {:castors, "_gear_castors", :boolean},
    {:cycle_time, "_cyc_time", :float},
    {:steer_lo_speed, "_steerdeg_lospeed", :float},
    {:steer_hi_speed, "_steerdeg_hispeed", :float},
    {:load_fraction, "_gear_load_fraction", :float}
  ]

  @weight_station [
    {:name, "_name", :string},
    {:weight_now, "_w_now", :float},
    {:weight_max, "_w_max", :float},
    {:weight_test, "_w_test", :float},
    {:arm, "_z_ref", :float}
  ]

  @light [
    {:type, "_lite_type", :integer},
    {:index_ref, "_index", :integer},
    {:distance, "_dist", :float},
    {:width, "_width", :float},
    {:hidden, "_hide", :boolean}
  ]

  @object [
    {:file, "_v10_att_file_stl", :string},
    {:part, "_v10_att_part", :integer},
    {:internal, "_v10_is_internal", :boolean},
    {:hide_dataref, "_obj_hide_dataref", :string},
    {:flags, "_obj_flags", :integer}
  ]

  @door [
    {:type, "_type", :integer},
    {:angle_now, "_ang_now", :float},
    {:extend_angle, "_ext_ang", :float},
    {:retract_angle, "_ret_ang", :float}
  ]

  @prefixes %{
    wing: "_wing",
    engine: "_engn",
    prop: "_prop",
    gear: "_gear",
    weight_station: "_cgpt",
    light: "_lite",
    object: "_obja",
    door: "_door"
  }

  @type field_spec :: {atom(), String.t(), :string | :float | :integer | :boolean}
  @type kind ::
          :aircraft | :wing | :engine | :prop | :gear | :weight_station | :light | :object | :door

  @doc "Field specifications for a kind."
  @spec fields(kind()) :: [field_spec()]
  def fields(:aircraft), do: @aircraft
  def fields(:wing), do: @wing
  def fields(:engine), do: @engine
  def fields(:prop), do: @prop
  def fields(:gear), do: @gear
  def fields(:weight_station), do: @weight_station
  def fields(:light), do: @light
  def fields(:object), do: @object
  def fields(:door), do: @door

  @doc "Property group prefix for a component kind (e.g. `:wing` -> `\"_wing\"`)."
  @spec prefix(atom()) :: String.t()
  def prefix(kind), do: Map.fetch!(@prefixes, kind)

  @doc "Read the top-level aircraft scalar fields into a `field => value` map."
  @spec read(Document.t(), :aircraft) :: map()
  def read(doc, :aircraft), do: read_fields(doc, @aircraft, & &1)

  @doc "Read one component (`kind`, `index`) into a `field => value` map."
  @spec read(Document.t(), atom(), non_neg_integer()) :: map()
  def read(doc, kind, index) do
    prefix = prefix(kind)
    read_fields(doc, fields(kind), fn suffix -> Array.key(prefix, index, suffix) end)
  end

  @doc "Set a top-level aircraft field by its semantic name (lossless writeback)."
  @spec put(Document.t(), :aircraft, atom(), term()) :: Document.t()
  def put(doc, :aircraft, field, value) do
    {^field, key, _type} = List.keyfind(@aircraft, field, 0)
    Document.put(doc, key, value)
  end

  @doc "Set a component field by its semantic name (lossless writeback)."
  @spec put(Document.t(), atom(), non_neg_integer(), atom(), term()) :: Document.t()
  def put(doc, kind, index, field, value) do
    {^field, suffix, _type} = List.keyfind(fields(kind), field, 0)
    Array.put(doc, prefix(kind), index, suffix, value)
  end

  defp read_fields(doc, specs, key_fun) do
    Map.new(specs, fn {field, suffix, type} ->
      {field, read_typed(doc, key_fun.(suffix), type)}
    end)
  end

  defp read_typed(doc, key, :string), do: Document.get(doc, key)
  defp read_typed(doc, key, :float), do: Document.get_float(doc, key)
  defp read_typed(doc, key, :integer), do: Document.get_integer(doc, key)
  defp read_typed(doc, key, :boolean), do: Document.get_boolean(doc, key)
end
