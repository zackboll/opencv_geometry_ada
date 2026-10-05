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

---

## Task 020: native safety gate

### Disposition and scope

**SAFETY_GATE_NOT_ESTABLISHED**.

The ownership conclusion above remains unchanged. Task 020 adds research
only, not `Fit_Line_3D`, a fitted-result type, shared point types, production
shim symbols, or any production source change. Geometry remains `0.2.0`
with `opencv_core >=0.2.0 & <0.4.0`. Core's unreleased 0.5.0-dev work is not
a dependency. Coverage remains **Deferred**, not Bound.

Positive results: count arithmetic and deterministic subset-selection
liveness are established; isolated probes cover all four exact runtime
versions; fully instrumented 4.10/5.0 campaigns report no ASan/UBSan faults.
Negative result: a **complete portable, rounding-aware arithmetic envelope
through both eigen backends has not been established**. In particular,
neither empirical successful fitting nor a finite output proves every
internal value was finite. There is no finding of an ordinary-finite-input
memory/liveness defect that would justify `UPSTREAM_NATIVE_BLOCKER`.

### Starting gate and unchanged baseline

- Fetched actual `origin/main`:
  `d3d9e53a1cce58176ef6746089aef7a385512870`.
- PR #18 is merged at that commit (2026-10-04); no open Geometry PRs
  existed. Initial tracked/untracked worktree was clean.
- Local/remote `0.2.0` tag object still
  `398215437bc872b2da02b30528aafd1788e70a50`, peeled commit still
  `42afa67a2f7c42c04612d3a019e5fdd029cea257`.
- Detached `/tmp/geometry-020-indexed-baseline` was created at fetched main,
  without copying ignored sibling-Core pins. `alr with --solve` resolved
  **indexed Core 0.3.0 (git origin)**, native OpenCV 4.10.0 (system origin),
  pkg-config 1.8.1. `alr -n build` and `alr -n -C tests run` passed:
  **524 registered/executed/successful**, no failed assertions/errors.
- Only then created `research/020-fit-line-3d-safety` from fetched main.
  No Core checkout, release tag, or release/index PR was modified.

### Probe, protocol, isolation, and replay

Research files, all opt-in and outside the default build/native test glob:

- `tests/native/research/fit_line_3d_probe.cpp`: one actual linked native
  `cv::fitLine` call per process, CV_32SC3 or CV_32FC3, all six distances.
- `scripts/run_fit_line_3d_research.py`: stdlib-only Linux controller,
  explicit build prefix, generation/replay, classification, self-tests,
  exact RNG certificate, report comparison/freezing.
- `tests/native/research/fit_line_3d_reproducers.txt`: JSONL cases with exact
  binary32 bits or original integers, including finite-but-wrong examples.
- `tests/native/research/fit_line_3d_evidence.json`: compact campaign
  counts, loaded-object hashes, fixture outputs, reproducer outputs,
  cross-build divergences, and liveness certificate. Full per-call stdout,
  stderr, wall times and input echoes remain in `/tmp/geometry-020/*.jsonl`;
  their hashes are recorded. They are not all checked into Git.

Protocol `FL3D1` supplies depth, model, three explicit scalar strings,
count, and XYZ triples. Float inputs use eight-digit binary32 hex bits;
scalars use binary64 hex strings (non-finite values are strings too).
The probe prints compile/runtime versions, `dladdr`'s defining fitLine
object, original input echo, result type/shape, six Float32 bit patterns,
finiteness, norm, and native elapsed time. Exception records retain code
and message. The controller records exit status, signal, timeout, stderr,
and wall time. It independently checks shape, bits, finiteness, norm and
sign-insensitive direction error; it checks the input echo and identity.
There is **no recentering, rescaling, or direction-sign normalization**.
Integers remain CV_32S until OpenCV's own conversion.

Every call runs in a child with a separate process group, a **3-second
hard wall timeout**, no core dumps and bounded output files (64 MiB each).
Timeout kills the process group and is recorded, never treated as a
production contract. Optional `--memory-mb` uses RLIMIT_AS; omit it under
ASan because ASan reserves a large virtual range. No dangerous native
in the Python process. JSONL reports flush/fsync each case;
resume rejects changed executable/corpus/version/prefix identities. An
interrupted partial JSON record fails loudly instead of silently discarding
prior evidence. LD_PRELOAD/LD_LIBRARY_PATH are removed; explicit rpaths
select non-system libraries. Each result records the loaded fitLine object
SHA-256. No native exception, signal, timeout, or sanitizer report occurred
in the completed campaigns below.

Example (absolute paths; replace the explicit native prefix as needed):

```sh
python3 /home/zboll/git/opencv/geometry/scripts/run_fit_line_3d_research.py build --include /usr/include/opencv4 --lib /usr/lib/x86_64-linux-gnu --backend imgproc --output /tmp/geometry-020/probe-410
python3 /home/zboll/git/opencv/geometry/scripts/run_fit_line_3d_research.py self-test --probe /tmp/geometry-020/probe-410
python3 /home/zboll/git/opencv/geometry/scripts/run_fit_line_3d_research.py certificate
python3 /home/zboll/git/opencv/geometry/scripts/run_fit_line_3d_research.py generate --output /tmp/geometry-020/replay.jsonl --seed 2020 --seeds 100
python3 /home/zboll/git/opencv/geometry/scripts/run_fit_line_3d_research.py run --probe /tmp/geometry-020/probe-410 --corpus /tmp/geometry-020/replay.jsonl --report /tmp/geometry-020/replay-report.jsonl --version 4.10.0 --object-prefix /usr/lib/x86_64-linux-gnu
```

The final generator has two extra tiny-parameter fixtures absent from the
earlier expanded corpus; those are runtime-tested in the separate boundary
campaign. Original corpus hashes/counts in the evidence must not be
confused with the current generator's count.

### Exact runtime provenance

All four versions were **runtime-tested**, not just source-inspected.
Each child verifies `cv::getVersionString()` and compile version exactly.

| Version | Native environment / defining fitLine object | Eigen backend |
| --- | --- | --- |
| 4.6.0 | Podman image `9216a90e0a3e26c147304d69b28f8bce87d5b0668627c03a81ef6d1b3f286e05`, Debian `4.6.0+dfsg-12`, `/usr/lib/x86_64-linux-gnu/libopencv_imgproc.so.406` | Eigen 3.4.0, build information |
| 4.10.0 | Host Debian `4.10.0+dfsg-5`, `/usr/lib/x86_64-linux-gnu/libopencv_imgproc.so.410` | Eigen 3.4.0, build information |
| 4.14.0 | `/tmp/geometry-020-install-414/lib/libopencv_imgproc.so.414` | Jacobi, WITH_EIGEN=OFF |
| 5.0.0 | `/tmp/geometry-opencv-5-install/lib/libopencv_geometry.so.500` | Jacobi, cvconfig.h has HAVE_EIGEN undefined |

The 4.6/4.10 distro builds report version-control identity `unknown`: they
are exact **release-version package runtimes**, not claimed byte-for-byte
unpatched upstream builds. Their immutable loaded-object hashes are in the
evidence. The 4.10 sanitizer build below is from a clean exact-tag checkout.

The reused 5.0 source directory misleadingly named
`/tmp/geometry-opencv-4.11` was checked read-only: clean, exact tag 5.0.0,
commit `40738fb16ceddb5fb3fea747585f7ce6abb0605b`; its build cache identifies
that source. 4.14's reused archive was compared against a fresh shallow
exact-tag checkout at `0654a42e19215ef25b1d367d822f3c630447e7c7`.
Recursive comparison found only omitted Git metadata files and an extra
download cache, **no source-content differences**. Its `linefit.cpp` and
`lapack.cpp` blobs are respectively
`67a3affccd2f33c0277c5fa6505278f9283a002b` and
`a23cec8496b5693f2d5659af18eef74972ed5a28`. A fresh Release core/imgproc
build used that verified archive. Directory names alone were not evidence:
a purported `features-opencv-410-install` was found to contain 4.1.0 and
was excluded.

### Arithmetic model: what is established, and what is not

Use **post-native-conversion binary32 coordinates** for the model. Let
`u=2^-24`, `gamma_k=k*u/(1-k*u)` when `k*u<1`, and `M` be the maximum
absolute coordinate. All following relative-error arguments assume
IEEE binary32 round-to-nearest, no fast-math, and need additive underflow
terms (or a separately justified subnormal/flush-to-zero model).
They are not valid merely because the host uses that mode.

#### Products, unweighted accumulation, means, and covariance

For each axis/pair compute, safely and with **outward rounding**, the nine
nonnegative aggregates:

```text
Sx = sum(abs(x)); Sy; Sz
Qx = sum(x*x); Qy; Qz
Cxy = sum(abs(x*y)); Cxz; Cyz
```

Individual native products and any partial sum are bounded by the absolute
aggregate, multiplied by product/summation rounding factors. A binary64
preflight must bound its own positive summation error too; plain binary64
`sum <= limit` is not an exact proof. Integer-safe/exact dyadic arithmetic
can alternatively evaluate the converted coordinates. For L2, the divisor
is `float(count)>0`; relative count rounding is at most `u`. Thus first
and second means can be bounded by the corresponding aggregate divided
by `count*(1-u)`, with summation/division errors. Subtraction requires
bounding **both** second mean and product of first means, not just Qx.
Each covariance is bounded by their absolute sum; each eigen diagonal is
the sum of two variance bounds. Cancellation reduces accuracy, not these
absolute upper bounds. `abs(x)<sqrt(FLT_MAX)` alone is insufficient because
count multiplies the accumulation budget.

The exploratory predicate in the runner uses `n<=2^20` and all nine
aggregates `<=2^120`. The exponent is a **front-end experiment budget**:
`(n+4)*u<0.063`, so `gamma_(n+4)<0.067`, and raw products/sums have over
200-fold headroom to FLT_MAX. It is **not an analytically certified factor
for the entire algorithm**, nor an accuracy criterion. No future binding
should copy these constants as a finished contract. In particular, count
caps solely to enable a relative-error bound should be reconsidered using
a stronger accumulation bound rather than accepted without justification.

#### Weights and weighted accumulation

Native initial subset weights are 0/1 with positive sum `min(n,10)`;
fallback weights are all ones. Raw robust weights are not what enters the
covariance fit: native sums them in binary64, divides in binary64, then
narrows to Float32, and the covariance routine accumulates total weight
in **binary32**.

If every raw weight is finite and nonnegative and the binary64 sum `S`
exceeds FLT_EPSILON, positive monotone summation gives `S>=w_i` for every
raw weight. Binary64 reciprocal/product rounding can exceed mathematical
1 only by binary64 ulps, far below the binary32 half-ulp above 1; therefore
the narrowed normalized weights are in `[0,1]` under round-to-nearest.
If `S<=FLT_EPSILON`, all-ones fallback also satisfies that bound. This
argument **does not apply to NaN, negative weights, directed rounding,
or unchecked overflow**. It also does not by itself bound `w0` away from
zero: that needs a lower bound for the normalized sum and binary32
accumulation, including underflow. A largest-weight argument gives a
weight on the order of `1/n`, not arbitrarily tiny, when normalization
is valid; a complete quantitative proof remains to be finished.

With valid weights, native `x*x*w` evaluates the unweighted product first.
Zero weights cannot rescue overflowing products. Weighted product/sum
upper bounds follow the same aggregate estimates because `w<=1`, but
division by `w0` requires its **lower bound**. Bounds on centroids and
covariance cannot assume they are exact convex combinations: numerator
and denominator accumulate separately with binary32 rounding.

#### Eigen arithmetic: residual portable blocker to the proof

Jacobi performs at most 270 pivot rotations. Its scaled `hypot` avoids
raw squares of large matrix elements, but one must bound
`W[l]-W[k]`, `abs(y)+hypot(p,y)`, `hypot(p,t)`, `(p/t)*p`, updated W,
and row/eigenvector rotations, including accumulated rounding. The pivot
test `abs(p)<=FLT_EPSILON` avoids a tiny pivot division in this backend.
Ideal orthogonal preservation of the matrix norm is **not** a proof that
the rounded rotations preserve it with the required headroom. A naive
per-rotation worst-case growth factor becomes excessively restrictive;
Task 020 does not impose that restriction merely to make the fit look safe.

OpenCV can instead use Eigen `SelfAdjointEigenSolver<MatrixXf>` and ignores
its boolean failure result in `fitLine3D_wods`. Task 020 inspected exact
Eigen 3.4.0
[SelfAdjointEigenSolver](https://gitlab.com/libeigen/eigen/-/blob/3.4.0/Eigen/src/Eigenvalues/SelfAdjointEigenSolver.h)
and
[Tridiagonalization](https://gitlab.com/libeigen/eigen/-/blob/3.4.0/Eigen/src/Eigenvalues/Tridiagonalization.h).
Scaling and bounded QR iterations are encouraging, but dynamic MatrixXf
uses the generic Householder path, not the compile-time 3x3 specialization.
Householder/Givens helpers, underflow/division branches and scaling/rescaling
still need a complete bound. Other configured Eigen versions also need an
explicit support argument. The distro Eigen runtimes were tested; the
fresh sanitizer builds used Jacobi. **No full eigen arithmetic proof is
claimed for either backend.**

Direction norm uses binary64 squares, narrows to binary32, applies a 1e-6
floor, and divides each component. A bound on finite, suitably sized eigen
vectors is a premise, not established by testing returned unit vectors.

#### Distances and convergence (conditional bounds)

Assume independently established centroid magnitude `<=B` and normalized
direction components `<=V` (near 1). Native Float32 differences are bounded
by `M+B`, with rounding. Each Float32 cross component is bounded by
`2*V*(M+B)` with multiplication/subtraction rounding. The distance is
at most `sqrt(3)` times that bound, evaluated with binary64 squares/sum
then narrowed. It must be below FLT_MAX with narrowing headroom. Summing
distances in binary64 is safe for signed-int counts under such a bound.
Convergence uses differences of two centroids and directions and their
cross products, so also bound `2B`, `2V`, and `8BV`, with rounding.
The three-term direction dot product must be finite before the native
clamp to [-1,1]; `acos` then has a valid argument.

For experiments the runner uses **conditional** `D=16*M` and robust
`D^2<=2^120`; this conservatively covers simple `B≈M,V≈1` estimates but
does **not prove those premises**. Aggregate bounds alone must be carried
through weighted division/eigen to make D rigorous. Just-outside cases
often still return good-looking results; that does not invalidate a
sufficient bound or establish a larger one.

### Per-distance scalar arithmetic

Scalars are narrowed from double to float before use. A future contract
must first reject non-finite/negative/out-of-Float32-range values; zero
selects native defaults. A positive double rounding to float zero also
selects the default: an API must deliberately document or reject that
behavior, not silently treat it as the positive original parameter.

| Model | Native arithmetic and needed premise |
| --- | --- |
| L2 | No distances/weights; parameter is unused. Count-dependent binary32 covariance is the principal concern. |
| L1 | `1/max(abs(double(d)),1e-6)`, then narrowing. For finite d, raw weight is positive, at most about 1e6 and finite. |
| L12 | **Float32 `d*d` first**, despite subsequent double `*0.5`/sqrt. Need D squared below FLT_MAX with rounding headroom; raw weight then in (0,1]. |
| Fair | Float32 `c=1/p` (or `1/1.3998f`), then `1/(1+d*c)`. Need finite positive c and bounded Float32 d*c and addition. Tiny positive p can overflow reciprocal; d=0 then causes `0*Inf` NaN. |
| Welsch | Float32 left-associated `-d*d*c*c`, c=`1/p` (default `1/2.9846f`), then exp. Need each stage bounded: D squared, D squared times c, D squared times c squared, including rounding. Tiny p reciprocal can overflow, then zero products can become NaN. Even finite reciprocal may overflow later stages. Huge p can underflow reciprocal/products to zero; normally finite weights then approach 1. Underflow is not the same as overflow/NaN. |
| Huber | p<=0 chooses 1.345f; positive finite p uses comparison then p/d. The division branch has d>=p>0; for nonnegative finite d raw weight is [0,1]. No reciprocal-of-parameter intermediate. |

Fair/Welsch therefore cannot use the existing 2-D finite/nonnegative scalar
contract **as an every-intermediate-finite proof**. A future 3-D gate needs
model-dependent predicates on the **effective narrowed parameter** and a
proven D, such as reciprocal and the above product-stage bounds, not an
arbitrary minimum parameter chosen by fuzzing. Overflow to negative infinity
in Welsch can give a finite zero weight; this does not meet this task's
stronger requirement that every relevant intermediate remain finite.

**Separate existing 2-D finding (no production fix here):** its scalar
validator permits finite positive p=2^-149 for Fair/Welsch. These models
share the same weight code and can form an infinite reciprocal/NaN weights
even with ordinary finite points. This is a gap in an *internal arithmetic*
safety claim, not a demonstrated memory-safety or liveness defect in the
released Ada 2-D binding. A finite final result may survive because the
robust routine retains an earlier candidate and NaN sum takes fallback.
Treat investigation/any correction as a separately authorized task.

Tiny-parameter fixtures (including zero-distance points and robust outliers),
negative/non-finite parameters, and accuracy scalars Inf/NaN/overflow/tiny
all returned finite unit directions in the recorded parameter campaigns.
That **does not certify their internal arithmetic** or authorize accepting
these scalar values. The probes intentionally call native code unfiltered.

### Integer conversion and accuracy

All integers in `[-2^24,2^24]` convert exactly to binary32. Beyond that,
only multiples of the binade's binary32 spacing are exact; other values
lose low bits. CV_32S's whole coordinate range remains finite after
conversion, but exact preflight must model that conversion, not original
integer squared sums alone. Adjacent integers can collapse to duplicates;
at 2^28 the binary32 spacing above the offset is 32. Stored spread-1,
spread-4, and spread-16 fixtures show loss of meaningful spread and
finite-but-wrong output. Native CV_32S is preserved in the probe.

The systematic accuracy corpus is **864 calls per runtime**: counts
2/16/128, offsets 2^0/2^10/2^16/2^20/2^24/2^28, directions X/Y/Z and
(1,2,3), both CV_32S/CV_32F, all six distances. All return finite unit
directions, but large errors occur **before integer rounding is necessary**.
Minimal example: `(65536,65536,65536)` and `(65536,65537,65536)`.
Native output can choose a direction perpendicular to Y, absolute dot 0,
angle 90 degrees, even though both input points are exactly represented.
The arbitrary diagonal also shows severe error (e.g. about 74.5 degrees).
This is cancellation in Float32 moment/covariance construction.

Do not call this a memory-safety failure. Finiteness and norm checks cannot
detect it. An offset/spread restriction would be an **accuracy contract**,
not a native arithmetic safety contract, and could reject normal translated
geometry. Recommended future semantics: document native precision limits
as for 2-D, do not promise translation-invariant accurate fitting, and do
not secretly center/scale. Task 020 does not choose an arbitrary accuracy
threshold as an input restriction. Users needing reliable accuracy must
choose an explicitly different numerical workflow/API.

### Degenerate and non-finite input

Every runtime/model tested one point, two identical points, two distinct
points, 32 identical points, all zeros, and duplicate-heavy arrays: **36/36
calls returned finite, norm≈1 results**. Near-collinear/noisy clouds are in
the deterministic campaign. Identical/all-zero inputs have no uniquely
defined geometric line; native picks a backend-dependent basis direction.
Float32 collapse has the same issue. Safe acceptance could document that
non-unique output rather than arbitrarily require three distinct points.
Two distinct points need not produce the correct direction at large offsets.

The 54 coordinate-nonfinite calls per runtime put NaN/+Inf/-Inf separately
in X/Y/Z, mixed with a finite point, over all distances: **9 non-finite
outputs, 45 finite but invalid all-zero directions**, no native exceptions,
signals/timeouts. Native code does not provide a useful semantic rejection.
Preflight rejection of every non-finite coordinate is essential.

Future publication must require correct six-float layout, all six finite,
and a **nonzero, non-near-zero direction with norm plausibly near 1**.
The research checks norm in [0.99,1.01]; this is a diagnostic tolerance,
not a formally derived future production tolerance. Reject a zero/subnormal
direction even when all values are finite. An ignored eigen failure can
leave zero vectors, and robust fits can retain zero output when every error
is invalid. These checks detect representation/normalization failures, not
rank deficiency, uniqueness, or finite-but-wrong geometry. A precise
norm-error bound and error-translation policy still require the eigen proof.

### Count and allocation proof

Native count and loop indexes are signed 32-bit `int`. Future count rules:

- L2: `1 <= n <= INT32_MAX`; returns before `AutoBuffer<float>(count*2)`.
- Robust: `1 <= n <= floor(INT32_MAX/2) = 1073741823`.
  `2*n<=2147483646`; the next count overflows signed multiplication.
- Independently require input addressability (`n*sizeof(Point3f)` and,
  when needed, integer conversion storage), and robust temporary
  addressability (`2*n*sizeof(float)`), within `SIZE_MAX`, supported object
  size/PTRDIFF_MAX and available allocator limits. Allocation failure must
  become a contained exception, never a published result. On 32-bit targets
  the byte-size bound is stricter than the signed robust count predicate.

No billion-point arrays were allocated. Exact Python integer self-tests
exercise these boundaries. Native practical stress counts reach 16384.
L2 count rounding and robust positive weight-sum precision remain part of
the numerical analysis; allocation arithmetic safety is a separate result.

### Deterministic subset-selection liveness certificate

This premise **is established**, not inferred from timed runs.

Exact state starts at UINT64_MAX (`RNG((uint64)-1)`, **not** default RNG's
0xffffffff). Each draw is:

```text
state = uint64(uint32(state)*4164903690 + uint32(state >> 32))
output = uint32(state)
uniform(0,n) = output % n
```

Native `--rng` first sixteen outputs were compared with the exact integer
model in all four environments. First three are 130063605, 3133359004,
2578348940. The certificate handles the **continuing state across all
20 restarts**, not only the first subset.

Proof reduction:

1. Partition the first 200 exact outputs into twenty ten-draw blocks.
2. For each block, enumerate every positive divisor of every nonzero
   pairwise absolute difference, retaining counts in [1,1073741823].
   Add counts 1..9 explicitly. Equal outputs would invalidate this
   reduction; the verifier rejects that condition.
3. For any noncandidate n>=10, every block has ten distinct residues,
   since a collision implies n divides that pairwise difference.
   Inductively each restart consumes exactly its next ten-draw block:
   all 20 finish in **200 draws**.
4. For every candidate, simulate all twenty duplicate-rejection loops
   over the same exact stream. Enumeration gives **13,135 candidates**.
   Worst total consumption is **599**, at n=10. The finite 4096-output
   prefix suffices; exhaustion would fail verification loudly.
5. Therefore all robust counts in the arithmetic-safe domain finish
   selection in at most **599 total draws**. Early termination of the
   fitting restarts only consumes a prefix, so cannot invalidate the bound.

Candidate-set SHA-256:
`ed72b735437e721a211103082ed5e9b93df4bfefffabddda6cbc37b5e78a43f0`.
4096-output prefix SHA-256:
`5054668c218165510a8377a0d0bccd977af903e64081776704d67eba7f5bae13`.
`certificate` regenerates factors/divisors and checks every candidate;
the fast self-test asserts the certificate's count/hash/bound.

Other fitLine loops have explicit count, 20 restart, and 30 iteration
bounds; Jacobi has 270. Optional Eigen has bounded iterative algorithms,
but its complete supported-version arithmetic/liveness audit remains part
of the unresolved portable backend premise. Allocation/OS progress is not
a hard real-time guarantee. A probe's wall timeout proves none of this.

### Runtime, sanitizer, stress, and cross-version evidence

Per exact release runtime, expanded campaign: **1812 calls** (seed 2020,
100 generated clouds × six models = **600 fuzz calls**, plus 1212 fixtures).
Families include random clouds, exact/noisy lines, thin near-lines,
power-of-two scales, extreme offsets, axis/diagonal accuracy, duplicates,
non-finites and scalar extremes. Additional **120 boundary calls/runtime**
cover aggregate-count/scale edges (16/1024/16384 points), tiny/huge
Fair/Welsch parameters, zero-distance/outlier cases and integer collapse.
This is structured characterization, not exhaustive proof or a claim of
a full ellipsoid/outlier distribution campaign. Boundary fixtures test
each proposed front-end predicate's motivation, not a completed accepted
domain. The exploratory pre-eigen filter's pass counts are recorded in the
evidence; all such calls returned finite norm≈1, but may be inaccurate.

| Runtime campaign | Returned finite unit direction | Non-finite result | Invalid direction |
| --- | ---: | ---: | ---: |
| 4.6 expanded | 1734 | 10 | 68 |
| 4.10 expanded | 1734 | 10 | 68 |
| 4.14 expanded | 1752 | 10 | 50 |
| 5.0 expanded | 1752 | 10 | 50 |
| Additional boundaries (each runtime) | 120 | 0 | 0 |

Fully instrumented **exact-tag** builds were created for 4.10.0 (clean
`71d3237a093b60a27601c20e9ee6c3e52154e8b1`) and 5.0.0 (clean commit above):
Debug core+imgproc or core+geometry, WITH_EIGEN/IPPs/OpenCL/ITT/LAPACK off,
`-fsanitize=address,undefined` on **both C and C++ library compilation**, not
just the probe. CMake caches/build.ninja and undefined `__asan_*` /
`__ubsan_*` symbols were checked in native Core and fitLine-defining objects.
Probe also instrumented, with libstdc++ assertions and `-no-pie`.
ASAN_OPTIONS disables leak detection and aborts on errors;
UBSAN_OPTIONS halts on errors. Sanitizers do **not** diagnose ordinary
floating-point overflow/NaN. No 4.14 sanitizer campaign was claimed.

Each instrumented runtime ran **1704 original cases + 120 boundary cases**,
including the 600 fuzz calls and all six models. Original campaign: 1644
finite-unit returns, 10 non-finite, 50 invalid directions; boundary campaign
120 finite-unit returns. **Zero sanitizer reports, signals, timeouts, or
exceptions**. Library prefixes are `/tmp/geometry-020-asan-install-410` and
`/tmp/geometry-020-asan-install-500`; loaded-object hashes in evidence.
This supports memory-safety observations for these calls, **not** universal
arithmetic certification, optional Eigen certification, or GNATprove.

Cross-version comparison preserves **480** meaningful direction/exit divergences
in the compact evidence; no bit-for-bit equivalence is required. The
Eigen distro pair and Jacobi pair differ strongly on offset/cancellation
and degenerate cases; extremes can differ in return vs zero direction.
No safety-class signal/timeout/sanitizer divergence was observed. Some
directions repeat identically within a build (self-test replay verifies
that), but cross-backend determinism or accuracy is not promised.

### Proposed future preflight: deliberately incomplete

There is **no complete accepted Ada contract to implement yet**. Established
pieces are finite coordinates/scalars, exact conversion-aware aggregate
accounting, separate L2/robust signed-count and addressability rules,
model-dependent effective-parameter products, the RNG certificate, and
post-native layout/finiteness/nonzero-direction checks. Remaining premises:

1. Outward-rounded aggregate limits derived through weighted total-weight
   lower bounds, covariance and **every supported eigen backend**, including
   tiny/subnormal and rounding-mode behavior, without arbitrary rejection
   simply to make native fitting appear safe.
2. A justified distance bound from those centroid/direction bounds and
   reciprocal/product headroom for Fair/Welsch/L12.
3. A derived direction normalization tolerance and a backend-failure model
   sufficient to ensure no invalid internal arithmetic is hidden by a
   finite earlier robust candidate.

Future work can close this with a rounding-aware interval/error proof,
exactly specified eigen backend/version support and targeted Eigen
instrumentation, then fuzz the **proven** accepted domain. The exploratory
`2^120`, `2^20`, `16*M`, and [0.99,1.01] diagnostics are not substitutes.
Normal cancellation/rounding accuracy limitations should remain documented
separately. An empirical campaign alone cannot close these premises.

### Verification and review boundary

Research runner fast self-tests cover CLI rejection, exact Float32 parsing,
serialization/corpus replay, malformed native input, timeout classification,
native RNG prefixes, certificate verification, exact count arithmetic,
native deterministic replay and resume-without-duplication. **Eight Python
unit tests plus native checks pass**. No proof-scope Ada source changed:
GNATprove/GNATformat are not applicable and were not run for this task.

Production verification is performed in the clean indexed-Core detached
baseline rather than the working checkout's ignored incompatible sibling
pin. Production test-count delta is zero: **524/524**. No public semantic
validation is duplicated in the C++ shim; the production shim is untouched.
Research predicates are explicitly not a production validation layer.

Fresh read-only review challenges the distinction between experiment
budgets and proved bounds, weighted normalization versus raw weights,
Float32-before-double products, tiny Fair/Welsch parameters, all twenty
RNG rounds, size_t versus signed-count safety, Eigen versus Jacobi evidence,
and finite-but-wrong versus invalid output. It found/fixed the report
comparison's empty-intersection issue (different corpora), and added native
echo checks, finite-flag verification and resume replay tests. No claim that
timed completion/fuzzing proves liveness or universal arithmetic remains.
