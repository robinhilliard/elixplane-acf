# elixplane-acf

Read, edit and write X-Plane 11 `.acf` aircraft files (and the `.afl` airfoils
they reference) from Elixir, with **byte-exact round-trips** and a **semantic
aircraft model**.

This is a companion to [elixplane](https://github.com/robinhilliard/elixplane),
which talks to a *running* X-Plane instance; `elixplane_acf` works with the
aircraft files on disk.

The `.acf` format is undocumented, proprietary and version-dependent. To stay
safe for use with Plane-Maker, the core guarantee is that reading a file and
writing it back reproduces the original **byte-for-byte** unless you explicitly
change something - only the lines you touch change. This has been verified
against a corpus of real X-Plane 10 and 11 aircraft (`.acf`) and their airfoils
(`.afl`).

## Installation

Add `:elixplane_acf` to your deps in `mix.exs`:

```elixir
def deps do
  [
    {:elixplane_acf, "~> 0.1"}
  ]
end
```

## Quick start

```elixir
# Parse, read, edit, write - the change is the only difference on disk
{:ok, acf} = XPlane.Acf.read("Cessna_172SP.acf")

XPlane.Acf.get(acf, "acf/_ICAO")                 #=> "C172"
XPlane.Acf.get_float(acf, "_engn/0/_max_thrust") #=> 1100.0

acf
|> XPlane.Acf.put("acf/_ICAO", "C175")
|> XPlane.Acf.write!("Cessna_172SP_mod.acf")
```

## The lossless property layer

Properties are addressed by their raw, version-specific key. Values are kept as
strings and only coerced when you ask:

```elixir
XPlane.Acf.get(acf, "acf/_name")          # raw string
XPlane.Acf.get_integer(acf, "_cgpt/count")
XPlane.Acf.get_boolean(acf, "acf/_is_glider")

acf = XPlane.Acf.put(acf, "_wing/0/_Croot", 5.25)  # typed value, formatted
acf = XPlane.Acf.delete(acf, "acf/_ICAO")
XPlane.Acf.keys(acf)                                # all property names
```

Indexed groups (wings, engines, gear, ...) are often sparse and carry a
`<group>/count`. `XPlane.Acf.Array` helps:

```elixir
XPlane.Acf.Array.indices(acf, "_wing")   #=> [0, 8, 9, ...] (only populated)
XPlane.Acf.Array.count(acf, "_wing")     #=> 56 (declared)
XPlane.Acf.Array.get_float(acf, "_wing", 0, "_Croot")
```

## The semantic aircraft model

`XPlane.Acf.aircraft/1` builds a typed, curated view over the property core:

```elixir
plane = acf |> XPlane.Acf.aircraft()

plane.name              #=> "Cessna 172SP"
plane.mass_empty        #=> 767.0
length(plane.wings)
hd(plane.engines).type
hd(plane.gears).leg_length
```

Components include `wings`, `engines`, `props`, `gears`, `weight_stations`,
`lights`, `objects` and `doors`. The full property set is always reachable
through the property/array API above; the semantic layer just covers the most
useful, human-meaningful fields.

To edit through semantic names while keeping the round-trip guarantee, change
the document and rebuild:

```elixir
doc   = XPlane.Acf.Schema.put(acf, :wing, 0, :root_chord, 5.25)
plane = XPlane.Acf.aircraft(doc)
```

## External assets

`.acf` files reference airfoils (`.afl`), attached objects (`.obj`) and
annunciator sounds (`.wav`). Enumerate, check and rewrite them:

```elixir
XPlane.Acf.assets(acf)                 #=> [%XPlane.Acf.Asset{kind: :airfoil, ...}, ...]
XPlane.Acf.Asset.missing(acf)          # references with no file on disk

# Relocate all airfoils into an airfoils/ subfolder, losslessly
XPlane.Acf.Asset.rewrite(acf, fn
  %{kind: :airfoil} = a -> Path.join("airfoils", Path.basename(a.path))
  _ -> nil
end)
```

## Airfoils (`.afl`)

`XPlane.Airfoil` reads and writes `.afl` files (version 700 / 900 / 1110), again
with a byte-exact round-trip, and exposes the polar curves:

```elixir
{:ok, foil} = XPlane.Airfoil.read("airfoils/clark-y_9.afl")
foil.version                    #=> 1110
length(foil.polars)             #=> 3
hd(foil.polars).reynolds        #=> 0.28
hd(foil.polars).points |> hd()  #=> {-180.0, 0.2255, 0.047, 0.05637}
```

`XPlane.Acf.load_airfoils/2` resolves a wing's airfoil references (searching the
`airfoils/` subfolder by default), parses each file once, and attaches the
`XPlane.Airfoil` structs to the wings:

```elixir
plane =
  "Cessna_172SP.acf"
  |> XPlane.Acf.read!()
  |> XPlane.Acf.aircraft()
  |> XPlane.Acf.load_airfoils()

hd(plane.wings).airfoil_files   #=> %{root_1: "clark-y_16.afl", tip_1: "clark-y_9.afl", ...}
hd(plane.wings).airfoils        #=> %{root_1: %XPlane.Airfoil{}, ...}
```

## Generating docs

```sh
mix docs
```

## License

MIT. See [LICENSE](LICENSE).
