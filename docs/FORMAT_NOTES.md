# ACF / AFL format notes (from Plane Maker debugging)

Practical knowledge for validating and extending `elixplane_acf`. Source of experience: parametric dronepeg export vs a Plane Maker–saved oracle (X-Plane 11). Export-side workflow lives in the dronepeg repo (`docs/XPLANE_EXPORT.md`).

The library’s core guarantee remains **byte-exact round-trip**. The notes below are **semantic / safety** knowledge — candidates for future validators and richer `Wing` / `Part` models — not changes to the lossless property layer.

## Layers inside one `.acf`

| Layer | Keys (examples) | Role |
|-------|-----------------|------|
| Lifting aero | `_wing/<n>/…` | Authoritative for physics and for PM’s open-time wing mesh build |
| Part placement + spline | `_part/<n>/_part_x/y/z`, `_geo_xyz`, `_s_dim`, `_r_dim` | Wings: cache that must agree with `_wing`. Bodies (e.g. fuselage): `_geo_xyz` **is** the shape |
| Airfoil refs | `_wing/<n>/_afl_file_{R0,R1,T0,T1}` | Paths to `.afl` on disk |
| Attached objects | `_obja/…` + external `.obj` | Visual; independent of wing aero join |

**Implication for tools:** parsing or rewriting properties without understanding `_wing` vs `_part` will miss the bugs that matter in Plane Maker. A file can round-trip perfectly and still cold-load with a mangled wing.

## Cold-load vs “wing tab fix”

Plane Maker often **regenerates** wing `_part` meshes from `_wing` + `.afl` when the user opens a wing tab. Symptoms that vanish after a tab visit are usually:

1. Inconsistent or truncated **element arrays** vs `_els` (confirmed root cause in one export), or
2. Bad / missing wing `_geo_xyz` relative to `_wing` + placement.

They are **not** proof that the on-disk ACF was fine for cold load. Automated tests that only open PM and dismiss dialogs will miss join geometry errors.

## Element-array invariant (high priority for a validator)

On XP11 wing slots observed in Decathlon / dronepeg:

- Control/incidence arrays are stored as indexed props with a sibling `/count`, e.g. `_wing/10/_flap1/0` … and `_wing/10/_flap1/count`.
- Writers commonly **pad** these arrays to length **10**.
- `_wing/<n>/_els` is the active element count used by PM.

**Invariant:** `1 ≤ _els ≤ 10` and `_els ≤ count` for every element array that PM reads at open (`_flap1`, `_ailn1`, `_elev1`, `_inc_elev1`, `_rudd1`, `_incidence`, and flap chord-ratio arrays when present).

If `_els` is larger than the padded array length, PM’s open-time mesh path can read past the arrays and corrupt the panel (outboard wing looked rotated / too long) until a wing tab rebuilds from airfoils.

**Suggested API (future):** e.g. `XPlane.Acf.Validate.wing_elements/1` → `{:ok, acf} | {:error, [%Issue{}]}` listing slot, `_els`, and short array counts. Optional strict mode in `read/2`.

## `_wing` vs `_part` (wings)

- `_crib_x/y/z_arm` — rib stations in aircraft coordinates (XP feet, CG origin).
- `_part_x/y/z` — part origin (often crib[0]).
- `_geo_xyz` — `s_dim × r_dim` control grid. For wings in PM-saved files this is effectively **aircraft-frame** (span along dihedral in XY, chord along Z, QC at origin, plus part origin), not a simple “crib overlay” of local rings.
- `_s_dim` — active station count (may differ per wing; do not assume template default).
- Points 14–17 on wing sections are often span-parameter knots, not airfoil outline.
- Omitting wing `_geo_xyz` while keeping `_wing` + placement does **not** reliably yield a correct cold-load (PM does not always regenerate before first draw).

Body parts (fuselage) remain a separate encoding problem: treat `_geo_xyz` as authoritative.

**False invariant:** `geo[si, 0] == crib[si]` for all stations — only true near root in some manuals; interior stations are a B-spline-style grid.

## Join / LE offset fields

- Joined panels use `_semilen_JND` and crib blending between parent tip and child root.
- `_c_off_for_RIB` should normally be **0**; non-zero “leading edge offset” in the UI can be **derived** from bad part/wing consistency rather than a deliberate export field.
- Semantic `Wing` today exposes chords/dihedral/airfoils; join/crib/element arrays are still property-layer concerns unless Schema grows.

## `.afl` airfoils

Format decode, structural invariants and parameter-line semantics: [`AFL_FORMAT_NOTES.md`](AFL_FORMAT_NOTES.md).

- Versions 700 / 900 / 1110 are already parsed with round-trip in `XPlane.Airfoil`.
- v1110 tables are always 721 rows on a fixed alpha grid; a parse that succeeds says nothing about whether X-Plane can fly the file.
- Asset enumeration via `_afl_file_*` + `XPlane.Acf.Asset.missing/1` remains the right first check.
- Cold-load and wing-tab rebuild both need resolvable paths; missing foils are a separate failure mode from `_els` corruption.
- No need for OBJ to validate aero join.

## Validation ladder (library + consumers)

| Level | What | elixplane-acf today | Gap / future |
|-------|------|---------------------|--------------|
| Syntax | Parse ACF / AFL | ✅ | Keep corpus round-trips |
| Assets | Airfoil/OBJ/WAV paths exist | ✅ `Asset.missing` | — |
| Semantic map | `aircraft/1`, `Wing`, … | ✅ partial | Crib, join, `_els`, `_part` dims |
| Structural safety | `_els` vs array counts; sane `_s_dim` | ❌ | Add `Validate` module |
| Oracle / shape | Diff `_geo_xyz` / crib vs known-good | ❌ (belongs in consumer or optional tool) | Optional analyze helpers |
| Plane Maker behaviour | Cold-load mesh / no MACIBM | ❌ (OS automation) | Document as out of scope; consumers own PM smoke |

**Important:** `read` success ≠ “safe for Plane Maker cold load”.

## Debugging playbook (for library tests / agent use)

1. Diff suspect ACF against a PM-saved oracle on **`_wing/*` first**, then `_part`.
2. Hybrid test: oracle `_part` + candidate `_wing` (or the reverse) to see which layer cold-load follows.
3. Absurd geo markers: if visuals ignore them until a wing tab, cold-load is driven by `_wing` (+ arrays), not the cache you think you are editing.
4. Always fully quit Plane Maker after replacing the file on disk.

## Out of scope for the lossless core

Do not break byte-exact round-trip to “fix” bad files. Validation and Schema enrichment should be **opt-in** layers on top of the property document.
