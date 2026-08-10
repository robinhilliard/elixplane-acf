# `.afl` airfoil format notes (v1110)

Findings from decoding the format against a stock X-Plane 11 install plus
third-party aircraft: **217 `.afl` files**, of which **214 files / 307 polar
tables** were used as the reference corpus.

**Provenance caveat:** every file in that install had just been rewritten by
Airfoil Maker's "re-save every airfoil in the latest format" pass, so the corpus
describes what Laminar's *writer* emits rather than a set of independently
authored files. That is still the right target for validation, but the observed
uniformity is partly an artifact of a single writer. A corpus assembled from
untouched installs would strengthen every claim below.

`XPlane.Airfoil` parses and round-trips these files today, but it exposes the
parameter line as an opaque `[float()]` and applies no structural validation.
Everything below is a candidate for `XPlane.Airfoil` / a future `Validate`
module.

## Structural invariants (zero exceptions in 217 files)

| Invariant | Value |
|-----------|-------|
| Byte-order line | `I` |
| Device line | `1234 device type code` |
| Shape control points | exactly **14** |
| Floats per polar parameter line | exactly **25** |
| Rows per polar table | exactly **721** |
| Alpha grid | 1° on −180…−21, **0.1° on −20.0…20.0**, 1° on 21…180 |

The fixed 721-row grid is the important one. A generator that emits a
different row count (we shipped 361 rows at uniform 1°) produces a file that
parses fine here but behaves pathologically in X-Plane, presumably because the
sim reads a fixed number of rows per table and then treats the following
parameter line as coefficient data.

**Suggested validation:** flag any table whose row count is not 721 or whose
alpha column deviates from the canonical grid. This is cheap and catches a
whole class of generator bugs that round-trip cleanly.

### Deliberately not invariants

- Table count varies: 1, 3, 4, 5, 9 and 10 all occur in the corpus
  (`Camberlift_2020.afl` has 5; TorqueSim BN-2 airfoils have 10). Do not
  assume a maximum.
- Periodicity `f(-180) == f(+180)` holds in most but not all tables
  (71 of 307 violate it), so it is a warning, not an error.
- Shape control point x-stations differ between files; only the count of 14 is
  fixed.

## Parameter line semantics

Decoded by regressing each slot against quantities derived from the tabulated
curve across all 307 reference tables. Match rate in brackets.

| Slot | Meaning | Confidence |
|------|---------|-----------|
| 0 | Reynolds number in **millions** | definitional |
| 1 | `dCl/dα` **per degree** | 100% |
| 2 | `Cl` at α = 0 | 100% |
| 3 | α at `Cl` min (negative stall angle) | 98% |
| 4 | α at `Cl` max (positive stall angle) | 91% |
| 7 | `Cl` max | 100% |
| 11 | `Cd` min | 99% |
| 19 | α low — abscissa for slot 22 | — |
| 20 | α high — abscissa for slot 23 | — |
| 21 | `Cm` max | 96% |
| 22 | `Cm` at α = slot 19 | 100% |
| 23 | `Cm` at α = slot 20 | 100% |
| 24 | `Cm` min | 95% |

Slots 5, 6, 8, 9, 10 and 12–18 are curve-shape exponents and secondary drag
terms; they did not decode confidently. Observed ranges: slot 5 `0…20`,
slot 6 `0.6…4`, slot 9 `0.06…2.9`, slot 14 `1.6…4.5`.

**Suggested API:** give `XPlane.Airfoil.Polar` named accessors for the decoded
slots (`cl_slope_per_deg`, `cl_at_zero_alpha`, `alpha_cl_min`, `alpha_cl_max`,
`cl_max`, `cd_min`, `cm_max`, `cm_min`) while keeping `params` as the
authoritative raw list for byte-exact round-trip.

**Suggested validation:** warn when a decoded slot disagrees with the value
derived from that table's own points beyond a tolerance. That mismatch is what
makes a file dangerous to open in Airfoil Maker.

## Airfoil Maker hazard worth documenting for users

Airfoil Maker renders its polar chart from the parameter line, not from the
tabulated rows, and **regenerates the ±20° rows from that line** on open or on
"convert all airfoils to latest format". A file whose parameter line does not
describe its own tables will be silently rewritten and lose its data.

This means a library-level "does the parameter line describe these points?"
check is more useful than it looks: it predicts whether a file survives a trip
through Laminar's own tooling.

## Related

- Consumer-side write-up with the generation policy that produced these
  findings: `dronepeg/docs/XPLANE_AIRFOILS.md`.
- ACF-side notes: [`FORMAT_NOTES.md`](FORMAT_NOTES.md).
