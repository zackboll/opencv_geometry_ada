# Task 019: 3-D fitLine ownership gate and source research

## Disposition

**Stopped at the public type-ownership gate. No production binding added.**

Recommend shared root `OpenCV` 3-D point values in a separately approved
Core task before implementing `OpenCV.Geometry.Fit_Line_3D`. This note is
source research and an ownership recommendation, not native safety
certification. No accepted numerical contract has been established and no
3-D runtime probes were run. The native safety gate remains unevaluated.

Geometry stays at `0.2.0`; its `opencv_core >=0.2.0 & <0.4.0` dependency,
public API, C ABI, native backends, and tests are unchanged.

## Starting evidence

- Fetched `origin`. Actual `origin/main`:
  `42afa67a2f7c42c04612d3a019e5fdd029cea257`.
- Local and remote annotated `0.2.0` tag object:
  `398215437bc872b2da02b30528aafd1788e70a50`; both peel to the commit above.
  Neither tag nor release submission was modified.
- Initial worktree was clean, on the old release-preparation branch.
  Local `main` was stale at `86a18b138acb74bddb4ddb18033c59d4341020a6`.
  It was fast-forwarded to `origin/main`, not reset or force-updated.
- No open Geometry PRs existed. Alire-index PR
  [#2202](https://github.com/alire-project/alire-index/pull/2202) was open
  and changed only `index/op/opencv_geometry/opencv_geometry-0.2.0.toml`.
- Required unchanged release baseline: `alr -n build` and
  `alr -n -C tests run` passed on the release commit, native OpenCV
  **4.10.0 / imgproc**. **524 registered/executed/successful**, zero failed
  assertions, zero unexpected errors. The log contained 524 `OK` entries.
- An earlier run on stale local main passed 377 tests; it is **not** the
  release baseline and is not included in the 524-test evidence.
- Both crates retain pre-existing ignored local Alire pins to sibling
  `/home/zboll/git/opencv/core`, currently version `0.4.0`. This baseline
  is pinned-environment evidence, not clean indexed dependency resolution.
  Published indexed Core 0.3.0's root spec was also inspected read-only.
- Branch `feature/019-fit-line-3d` was created only after the release
  starting gate and 524-test baseline passed.

## Public 3-D value ownership

Both the sibling Core root spec and indexed Core 0.3.0
`src/opencv.ads` explicitly assign reusable public values to `OpenCV`,
distributed by `opencv_core`; `OpenCV.Core` owns Mat-specific abstractions.
They contain `Point`, `Point_Array`, and `Float32_Point`, but no 3-D point.
Native `Point3_`, `Point3i`, and `Point3f` are themselves Core values:
`modules/core/include/opencv2/core/types.hpp`, lines 238-291 in 4.10.0.

### Alternatives

| Alternative | Benefit | Cost / disposition |
| --- | --- | --- |
| A: Geometry-owned ordinary records and arrays | Permitted when Geometry requires a type absent from Core; avoids a prerequisite release | A generic coordinate is not Geometry-specific. Future Calib3D/3-D bindings would either depend on Geometry for a fundamental value or introduce a second distinct point type. Moving a published distinct Ada type later risks source compatibility. Reject for this feature. |
| B: Shared root `OpenCV` records and arrays | Matches existing reusable point ownership and native Core Point3 placement; allows future module reuse without Geometry dependence | Requires explicit Core owner approval, additive Core changes, testing, and a released dependency containing the types. Recommended prerequisite. |
| C: Another ordinary Geometry value record | Could use a different name, such as a spatial position | Renaming the same generic X/Y/Z concept does not resolve ownership. An operation-specific input record would still need conversions for future reuse. No materially clearer alternative found. |

Do not use Mat, tuple-like numeric arrays, C structs, or controlled objects
to avoid the decision. A Geometry-local alias to a future root type would
be possible only after the shared type exists; it is not a reason to
publish a distinct local type first.

The architecture permits Geometry-local values but does not require them.
For reusable 3-D coordinates, shared ownership is clearly preferable to
creating migration debt merely to bind one more mode. This activates Task
019's explicit stop rule. It does not change repository architecture or
authorize edits to Core.

### Recommended Core follow-on API (proposal, not declarations added)

Add the following ordinary values to Core's `src/opencv.ads`, alongside
the existing integer and Float32 point families:

```ada
type Point_3D is record
   X : Point_Coordinate := 0;
   Y : Point_Coordinate := 0;
   Z : Point_Coordinate := 0;
end record;

type Point_3D_Array is array (Natural range <>) of Point_3D;

type Float32_Point_3D is record
   X : Float32_Value := 0.0;
   Y : Float32_Value := 0.0;
   Z : Float32_Value := 0.0;
end record;

type Float32_Point_3D_Array is
  array (Natural range <>) of Float32_Point_3D;
```

Use `OpenCV.Point_3D` / `OpenCV.Float32_Point_3D`, not `OpenCV.Core` types.
The arrays have arbitrary Natural bounds, including nonzero lower bounds
and null ranges. Coordinate finiteness remains an operation-specific
policy, not a record invariant. No foreign representation clauses, native
allocation, shim changes, or Mat bridge are needed for these values.
`Fitted_Line_3D` would remain Geometry-owned because it is a fitted result.

The separate Core task should obtain naming/ownership approval, add these
four declarations and public documentation, and test defaults, copying,
array bounds, and existing client compatibility. Adding names is normally
additive, but broad `use OpenCV` clients should be checked for name clashes.
Do not silently relocate existing Geometry `Float32_Point_Array` or add
unneeded Float64 families as part of that prerequisite.

No indexed release currently inspected (through Core 0.3.0) supplies the
proposed values. Core 0.4.0 is already immutably tagged and submitted to
the Alire index in PR #2198 without these types; Core main has since moved
beyond that release. The shared 3-D point values must therefore first
appear in a subsequent Core release, not a retroactive change to 0.4.0.
A feature-bearing Core 0.5.0 is the natural target if the owner approves
this proposal, not an existing release commitment.

Geometry must then raise its minimum Core dependency to the first released
version that actually contains the shared types. If that is Core 0.5.0,
the expected constraint becomes `opencv_core >=0.5.0 & <0.6.0`. Merely
keeping `>=0.2.0` would falsely promise builds against versions without
the types. This is a future dependency decision only: no manifest change
is made in PR #18. Geometry remains version `0.2.0` with its current
`opencv_core >=0.2.0 & <0.4.0` dependency. Core ownership remains
recommended, and Geometry `Fit_Line_3D` remains deferred until the shared
types exist in a released Core version and the separate native
arithmetic/liveness safety gate succeeds.

Proposed follow-on sequence:

1. **Core: shared 3-D point values**, owner decision, tests, release.
2. **Geometry: resume safe 3-D fitLine**, approved dependency update and the
   complete native arithmetic/liveness gate before production code.

## Exact upstream source comparison

Inspected the complete `linefit.cpp`, including dispatch, 3-D covariance,
distance calculation, weights, random restarts, and convergence. Exact
tag identities:

| Release | Peeled commit | Source |
| --- | --- | --- |
| 4.6.0 | `b0dc474160e389b9c9045da5db49d03ae17c6a6b` | [imgproc linefit.cpp](https://github.com/opencv/opencv/blob/4.6.0/modules/imgproc/src/linefit.cpp) |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` | [imgproc linefit.cpp](https://github.com/opencv/opencv/blob/4.10.0/modules/imgproc/src/linefit.cpp) |
| 4.14.0 | `0654a42e19215ef25b1d367d822f3c630447e7c7` | [imgproc linefit.cpp](https://github.com/opencv/opencv/blob/4.14.0/modules/imgproc/src/linefit.cpp) |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` | [geometry linefit.cpp](https://github.com/opencv/opencv/blob/5.0.0/modules/geometry/src/linefit.cpp) |

The 4.6/4.10/5.0 local source files were checked against their exact Git
HEADs. The 4.14 source archive was verified against upstream exact-tag blob
identity `67a3affccd2f33c0277c5fa6505278f9283a002b`. Its Core `lapack.cpp`
also matches exact-tag blob `a23cec8496b5693f2d5659af18eef74972ed5a28`.

Full `linefit.cpp` SHA-256:

| Release | SHA-256 |
| --- | --- |
| 4.6.0 | `91b6721d6e52f818f259cbb341007d80db90f874b330bd42d9775f0a76f47dc6` |
| 4.10.0 / 4.14.0 | `e7d88be5052d68a41c4f51f71c07eaef7370ae2d87707133196a1edc9f25f950` |
| 5.0.0 | `ad52edf91c7c3ba0e0df5e9d4a02f721a884d91d822712dbf445caaa0537677e` |

Findings, not assumptions of identity:

- 4.10.0 and 4.14.0 `linefit.cpp` are byte-identical.
- 4.6.0 differs from 4.10.0 only in qualified distance/error constant
  spellings in the 2-D and 3-D switches; no changed arithmetic was found.
- 5.0.0 changes 3-D convergence `acos` to `std::acos`. Its other changes
  are 2-D `cos`/`sin`/`acos` qualification and removal of legacy `cvFitLine`.
  The 3-D accumulation and weighting expressions are unchanged, but the
  complete implementation is **not** byte-identical across all releases.
- Public declarations remain the six-argument InputArray/OutputArray API:
  4.6 `imgproc.hpp:4325`, 4.10 `imgproc.hpp:4390`, 4.14
  `imgproc.hpp:4566`, 5.0 `geometry/2d.hpp:745`.
- Shared linefit source locations in all four versions:
  `fitLine3D_wods:100-202`, `calcDist3D:225-250`, weights `252-309`,
  `fitLine3D:463-603`, dispatch `607-635`.
- Core `lapack.cpp` `JacobiImpl_` is byte-identical across these versions
  (starting line 115). The entire `eigen` function is also byte-identical:
  4.6 lines 1381-1453, 4.10/4.14 lines 1331-1403, 5.0 lines 1332-1404.
  Whole `lapack.cpp` files differ outside these functions; this is not a
  claim that all Core dependencies or optional Eigen versions are identical.

## Arithmetic inventory for the resumed safety gate

These are source observations, **not an accepted-input proof**:

- Dispatch checks point dimensionality before converting non-CV_32F input
  to CV_32F. Integer Point3 input therefore reaches native conversion;
  low bits beyond binary32 precision can be lost. It publishes six floats
  `(vx, vy, vz, x0, y0, z0)`, without direction-sign normalization.
- `fitLine3D_wods` uses **binary32 accumulators** for coordinate sums,
  squared terms, cross terms, and total weight. The weighted second terms
  are `x*x*w`, etc.: an overflowing product is evaluated before a small or
  zero weight can reduce it. Reusing the 2-D `2**63` limit is unsound as an
  accumulation argument.
- Means and second moments divide by binary32 `w0`, then subtract products
  of binary32 means. Cancellation at large offsets with small spread can
  destroy covariance accuracy while leaving a finite result. Finite-only
  output checks cannot establish acceptable line geometry.
- The symmetric 3x3 eigen matrix contains sums of variances on its diagonal
  and negated covariances off-diagonal. Finiteness of individual products
  alone does not bound this matrix or subsequent eigen arithmetic.
- Native `eigen` optionally uses Eigen's SelfAdjointEigenSolver; otherwise
  it uses Jacobi (at most `3*3*30` iterations). Jacobi has an absolute
  binary32-epsilon pivot stopping test. Its scaled `hypot` helper avoids
  directly squaring large inputs but still has other arithmetic to bound.
  Eigen failure returns false; `fitLine3D_wods` ignores that return.
  Eigen outputs start zeroed, and direction normalization has a `1e-6`
  floor. A finite all-zero direction is therefore not a valid success test.
- Direction norm is computed from binary64 products, then narrowed to
  binary32. Point differences and cross-product expressions in
  `calcDist3D` are binary32 **before** assignment to doubles. Cross-product
  squares and their sum are binary64; distance is narrowed to binary32.
- For finite nonnegative distances and valid positive effective constants,
  raw L1 weights are positive and at most `1e6`; L12, Fair, Huber, and
  Welsch weights are mathematically in `[0,1]`. This is not a guarantee
  that native evaluation stays finite: L12 first evaluates `d*d` in
  binary32; Fair forms a binary32 reciprocal and `d*c`; Welsch evaluates
  `-d*d*c*c` in binary32 before `exp`, allowing overflow/underflow and
  problematic combinations such as infinity times zero. Scalar narrowing
  and tiny/huge explicit parameters must be included in preflight.
- The robust path sums weights in binary64 and normalizes there before
  narrowing each weight. If the sum is at most `FLT_EPSILON` in magnitude,
  it replaces every weight by `1.f`. Initial subset weights are 0/1.
  Thus raw L1's `1e6` maximum is **not** the weight supplied directly to
  the subsequent covariance fit. Rounding of normalized weights, positive
  total weight, and binary32 accumulation still need an explicit argument.
- Robust convergence forms a binary32 direction dot product, promotes it
  to double, clamps to `[-1,1]`, and tests the angle. Its radius test is
  the maximum absolute component of the cross product of changes in
  point and direction, **not** a bound on each point-coordinate change.
  Parameters/defaults and these tests must be documented from the 3-D
  source rather than copied from 2-D documentation.
- Reweighting has 20 restarts of at most 30 iterations. Subset selection
  has a duplicate-rejection loop without an explicit iteration cap;
  `RNG::uniform(0,count)` uses modulo in Core `operations.hpp:409`.
  A portable liveness argument must account for that loop; the outer
  iteration bounds alone do not establish it.
- L2 returns before `AutoBuffer<float>(count*2)`. Robust counts need the
  signed-integer multiplication bound before allocation, plus platform
  buffer-size/addressability limits. `w + count` relies on that allocation.
  Count-to-float rounding affects unweighted division and `count*FLT_EPSILON`.
  AutoBuffer uses stack storage or `new[]`; allocation errors must be
  contained by a future shim, not treated as a successful fit.
- Degenerate inputs reach eigen selection with a zero or poorly conditioned
  matrix. No direction for one point/identical points is certified here.

A resumed task should investigate binary64 preflight bounds on aggregate
absolute coordinates and squared magnitudes, with rounding headroom and
a separate offset/spread accuracy criterion. Such bounds are candidates,
not established sufficient conditions. They must cover every weighted fit,
eigen backend, distance and convergence intermediate, and scalar constant.
Do not silently recenter/rescale input or replace OpenCV's eigen algorithm
to avoid the gate: those would change the wrapped native computation.

## Verification boundary and remaining work

No public Ada operation, type, packing helper, C struct, entry point, or
shim guard was added. The C++ validation boundary is unchanged; there is
no new public semantic validation duplicated in the C++ shim.

Test-count delta: **0**, still **524**. The unchanged local normal baseline
is the only runtime evidence from this task. No 3-D probes (including
finite-but-wrong, robust, non-finite, or malformed ABI cases), exact 5.0
runtime runs, 4.14/4.6 runtime runs, or validation-profile runs were done:
the ownership stop precedes native certification and implementation.

Established GNATprove scope remains the prior **277/277** record. No
SPARK-compatible code changed, no new checks were introduced, and proof
was not rerun. This note does not claim proof of native OpenCV behavior.
No Ada source changed, so GNATformat and the Ada 79-column check have no
changed-source scope. Existing warnings-as-errors builds passed.

The follow-on must execute all requested native probes, normal/validation
profiles, ABI tests, proof of new Ada helpers, and independent review before
calling the binding safe. Source inspection of a release is not a runtime
test of that release. The unrelated safety deferrals (`approxPolyN`,
Float32 `minEnclosingTriangle`, `minEnclosingConvexPolygon`) remain intact.
