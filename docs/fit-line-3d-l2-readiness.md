# GEOM-028: 3D L2 line-fitting readiness

## Disposition

**SAFETY_GATE_NOT_ESTABLISHED.** No production feature implemented.
Shared point ownership is resolved; portable native numerical safety is
not. This is an L2-specific continuation of Tasks 019, 020 and 025, not a
repeat of their robust-metric fuzzing campaign. No new public declarations,
C ABI symbols, Ada dependencies, backend choices or CI policies.

The precise missing requirement is a **rounding-aware, input-checkable
arithmetic envelope through both configured `cv::eigen` paths**, including
small/subnormal values and the floating-point environment. That envelope
must bound intermediate eigenvalue/eigenvector operations, not only the
input matrix or returned line. Neither an arbitrary smaller coordinate
limit nor successful calls in this report establish it. No claim is made
that every possible restricted L2 domain is unsafe or impossible to prove.

## Repository and Core audit

- Fetched `origin/main`: **`ec4d689eac748b7837abd4c3754c3090ca4bf814`**.
  The initial worktree was clean; created `feature/028-fit-line-3d-l2`
  directly from that commit. Local `main` was not used as the baseline.
- Reviewed local/remote branches and all existing PRs. Related work is
  merged: #18 (019 ownership), #19 (020 native safety), #24 (025
  reassessment). No existing 028 branch or open feature PR was found.
- Inspected coverage, both historical research notes, thick Ada spec/body,
  shim header/implementation, manifests/GPR files, integer and Float32
  `Fit_Line_2D` tests. Existing 2D contracts are untouched.
- The community Alire index's `opencv_core-0.5.0.toml` points to commit
  **`f8aef00c5366b4275ccd3d934f9c73ea5b83cd4f`**. Inspected the released
  cached source, not just Core main: `src/opencv.ads` lines 90/97 declare
  `Point_3D` / `Point_3D_Array`; lines 130/137 declare
  `Float32_Point_3D` / `Float32_Point_3D_Array`. The source SHA-256 is
  `2ebf97ba3b08e88cef529f77e78cf896cab17fa24b7a6f3363db33016b58d076`.
- Geometry 0.3.1 already requires **`>=0.5.0 & <0.6.0`**. No Core change
  or minimum-version increase is necessary. Old ownership-blocker text in
  Tasks 019/020/025 is historical, superseded by this audit.
- Local production build has an ignored pin to the exact 0.5.0 fixture
  above. The tests crate has an existing ignored sibling-Core pin at
  `ccc2190f9bf0712d65a2b9d2983cde7ce68b4bae` (reports version 0.5.0,
  clean). These pins were not changed. Thus the 542-test results are
  **pinned-environment regression evidence**, not fresh indexed resolution
  or a new complete released-Core qualification matrix.

## Exact upstream source audit

| Release | Commit | fitLine source |
|---|---|---|
| 4.6.0 | `b0dc474160e389b9c9045da5db49d03ae17c6a6b` | `modules/imgproc/src/linefit.cpp` |
| 4.10.0 | `71d3237a093b60a27601c20e9ee6c3e52154e8b1` | same |
| 4.14.0 | `0654a42e19215ef25b1d367d822f3c630447e7c7` | same |
| 5.0.0 | `40738fb16ceddb5fb3fea747585f7ce6abb0605b` | `modules/geometry/src/linefit.cpp` |

The local 4.6/4.10/5.0 linefit files match the exact-tag Git objects.
4.14's annotated tag was resolved through GitHub; its linefit blob is
`67a3affccd2f33c0277c5fa6505278f9283a002b`, matching the local archive file.
4.10 and 4.14 linefit files have identical SHA-256
`e7d88be5052d68a41c4f51f71c07eaef7370ae2d87707133196a1edc9f25f950`.
The full 4.6 and 5.0 files differ in selectors/namespaces/removed legacy C
entry points, not the 3D L2 arithmetic. Other 4.x releases and distribution
backports are not newly qualified by this audit.

The inspected public declaration is
`fitLine(InputArray, OutputArray, int, double, double, double)`.
Its documentation specifies six Float32 outputs: direction followed by a
point. `fitLine3D_wods` (lines 100–207 in these files) accumulates **all
nine first/second moments in binary32**, unlike 2D's binary64 sums. It
divides by `float(count)`, subtracts products of means, forms a symmetric
3x3 inertia matrix, calls `eigen` **without checking its boolean result**,
selects the minimum eigenvalue's vector, and normalizes it with a 1e-6
floor. It does not center the points before accumulating.

### What L2 removes, and what it does not

`fitLine3D` returns at the L2 switch case (lines 478–479), before the
`AutoBuffer<float>(count*2)` allocation, random selection, distances,
weights and convergence loops. Parameter/reps/aeps can therefore be fixed
finite constants in a future L2-only ABI. The Task 020 robust RNG proof,
weight-sum lower bound and Fair/Welsch reciprocal bounds are **not L2
prerequisites**. They must not obscure the remaining eigen obligation.

For contiguous Float32 point input, `1 <= n <= INT32_MAX` is the signed
loop/count domain; separately require `12*n` addressable bytes within
`SIZE_MAX`, object/`PTRDIFF_MAX` limits and actual allocated storage.
For an integer overload, do not assume the same storage/conversion proof:
native `convertTo` uses shape-dependent scalar widths. A future binding
could explicitly convert and pack on the Ada side, but that conversion
must be qualified independently. No integer path is certified here.
The native count conversion remains finite and positive for every such n,
but rounding of that divisor belongs in the numerical error model.

### Front-end bounds are necessary, not sufficient

For round-to-nearest binary32, let `u=2^-24`. Where `ku<1`, ordinary
summation bounds use `gamma_k=ku/(1-ku)`. Outward-rounded aggregates of
absolute first moments and absolute products can bound every partial sum.
Bounds must then propagate through division by the rounded count, both
terms of each covariance subtraction, and sums of covariance diagonals.
Subnormal products require additive error terms; a relative-error-only
model is incomplete. Coordinate maxima alone omit the count-dependent
accumulation budget. The earlier exploratory `n<=2^20` / `2^120` aggregate
budget is still **not** a certified end-to-end domain.

New exact example: eight alternating `(s,s,s)` and `(-s,-s,-s)` points,
`s=2^63`. Every individual square is exactly `2^126`, finite, yet the
fourth positive square accumulation reaches `2^128`, beyond binary32.
Thus even importing 2D's justified `2^63` coordinate limit is unsafe for
3D. This is an analytical counterexample to that proposed shortcut, not
just a fuzz observation. Smaller inputs can still demand a backend proof.

### Eigen backends and liveness

In `modules/core/src/lapack.cpp`, the relevant `JacobiImpl_`, scaled
`hypot`, and `eigen` paths were compared across the four sources. Other
lapack changes do not alter those paths. Jacobi has a maximum of 270
rotations for n=3. Its pivot cutoff is the **absolute** Float32 epsilon.
Above that cutoff, `W[l]-W[k]`, `abs(y)+hypot(p,y)`, normalization,
eigenvalue updates and rounded rotations still require bounds. Ideal
orthogonality alone does not establish rounded intermediate finiteness.

With `HAVE_EIGEN`, OpenCV uses **dynamic `MatrixXf`**, not a fixed 3x3
solver. Inspected Eigen 3.4.0 (Debian 3.4.0-5) generic
`SelfAdjointEigenSolver.h:420–467`, `Tridiagonalization.h:428–456`,
`Householder.h:67–95`, and QR code in the same solver header. It scales
the lower triangle by its maximum magnitude (zero becomes scale 1),
uses generic Householder tridiagonalization, bounded QR, then rescales
eigenvalues. Householder has a minimum-normal squared-tail test. QR
explicitly handles underflow of the Wilkinson-shift square, but that
branch is not a proof of all divisions/rotations under all accepted
inputs. QR performs at most `30*n=90` steps, then reports nonconvergence;
OpenCV returns false, which fitLine ignores. Other Eigen versions and
floating-point configurations remain an explicit portability premise.

The L2 native algorithm has no robust retry liveness issue. Source gives
bounded count/eigen loops for these backends; this is not a hard real-time
guarantee for allocation/OS/library instrumentation. Native exceptions
can be contained by the established shim design, but exception handlers
do not catch floating-point flags or undo invalid internal arithmetic.
No new memory fault or unbounded L2 loop is claimed.

## New reproducible floating-point-environment evidence

Opt-in Linux standalone probe:
`tests/native/research/fit_line_3d_l2_fenv.cpp`. It calls stock
`cv::fitLine`, prints separate header/runtime versions, both loaded
objects, and native build information. It masks traps, clears flags
immediately before the call, captures flags immediately afterwards, then
checks output in binary64. It restores the original environment at exit.
No replacement algorithm, production preflight, process-isolated API or
shim is introduced. External timeout is only a research safeguard.
Exit zero means the observations completed, **not** that the native
results met a safety or accuracy contract. The deliberately overflowing
cases are negative research fixtures, not proposed accepted inputs.

Each executable performs **304 calls**: four exact fixture families ×
19 power-of-two scales × four rounding modes. Families are diagonal,
Y-axis, coincident and eight-point diagonal accumulation stress. Rounding
modes are nearest/downward/upward/toward-zero. No FTZ/DAZ campaign or
unmasked-trap qualification is claimed. Flags cover the whole native call,
not a source-line trace; the accumulation overflow above is independently
located by exact arithmetic. Underflow alone is not treated as a fault.

Selected observed facts (the probe prints hexadecimal values):

| Input / environment | Jacobi | Eigen 3.4.0 |
|---|---|---|
| Eight alternating points, s=2^63, nearest | finite unit Z direction; `FE_OVERFLOW` and `FE_INVALID` set | finite zero direction; overflow and invalid set |
| Same, toward-zero | finite near-unit diagonal; overflow set | finite near-unit diagonal; overflow set |
| Two opposite diagonal points, s=2^-12, nearest | finite unit Z direction, no invalid/divzero/overflow | near-unit diagonal, no invalid/divzero/overflow |
| Two opposite diagonal points, s=2^-70, nearest | unit Z direction | near-unit diagonal, underflow flag |
| Three identical points (1,1,1), nearest | unit arbitrary direction through the point | unit arbitrary direction through the point |

In particular **finite, nonzero, unit-length output is not evidence of
finite internal arithmetic**, even for L2. A direction/residual check
also cannot turn a post-call check into pre-call numerical safety.
The 2^-12 Jacobi case is an accuracy/scale-invariance limitation caused
by the absolute pivot cutoff, **not** by itself a memory/liveness blocker.
Coincident input need not have a unique direction. No arbitrary minimum
spacing or maximum coordinate is promoted to an accepted contract.

### Runtime matrix and limits

All local probe runs use Linux x86_64, GCC 14.2.0, no fast-math in the
probe. Each cell below completed 304 calls under a 30-second outer limit.

| Native runtime | Eigen backend | Build used |
|---|---|---|
| 4.6.0 | Jacobi | existing exact-tag `/var/tmp/geometry-027c1/install-4.6.0` |
| 4.10.0 | Eigen 3.4.0 | host Debian `/lib/x86_64-linux-gnu` |
| 4.10.0 | Jacobi + ASan/UBSan | existing fully instrumented `/var/tmp/geometry-026/install-asan-4.10.0` |
| 4.10.0 | Eigen 3.4.0 | fresh exact-source `/tmp/geom028/build-eigen` |
| 4.10.0 | Eigen 3.4.0 + ASan/UBSan | fresh exact-source `/tmp/geom028/build-eigen-asan` |
| 4.14.0 | Jacobi | existing exact-tag `/var/tmp/geometry-026/install-4.14.0` |
| 5.0.0 | Jacobi | existing exact-tag `/var/tmp/geometry-026/install-5.0.0` |

These are **native research runs**, not whole Ada-suite qualification on
each version. The existing sanitizer Core lapack and Imgproc linefit
objects both have ASan/UBSan references; the probe is instrumented too.
No sanitizer diagnostic occurred. The fresh Eigen-enabled sanitizer build
also completed 304 calls, with empty diagnostic stderr. Its Core lapack
and Imgproc linefit objects contain both ASan and UBSan references.
In total: **2,128 calls across seven build cells** (including two
instrumented cells), no C++ exceptions, signals or timeouts. Ordinary
floating-point overflow and invalid results are **not** diagnosed by
these sanitizers. No new 4.6, 4.14 or 5.0 sanitizer result is claimed.

Eigen-enabled 4.6/4.14/5.0, other Eigen versions, macOS/libc++, Windows
MSYS2, Debian 12 GNAT 12 and other architectures were not newly run.
Existing workflows/requirements are unchanged. The Windows job is
intentionally skipped on PRs/feature pushes and retained for main pushes
and manual dispatch. Linux success is not cross-platform qualification.

### Reproduction

From the repository root, for an installed native prefix (use `opencv5`
and `geometry` instead of `opencv4` and `imgproc` on 5.0):

```sh
p=/absolute/path/to/opencv-prefix
g++ -std=c++17 -O2 -g -frounding-math -fno-fast-math \
  -Wall -Wextra -Wpedantic -Werror -I"$p/include/opencv4" \
  tests/native/research/fit_line_3d_l2_fenv.cpp \
  -L"$p/lib" -Wl,-rpath,"$p/lib" -lopencv_imgproc -lopencv_core -ldl \
  -o /tmp/fit-line-3d-l2-fenv
timeout 30 /tmp/fit-line-3d-l2-fenv
```

For a fully ASan/UBSan-instrumented native prefix, also compile the probe
with `-fsanitize=address,undefined -fno-omit-frame-pointer -no-pie`, then
run with `ASAN_OPTIONS=detect_leaks=0:abort_on_error=1` and
`UBSAN_OPTIONS=halt_on_error=1`. Instrumenting only the probe is not
native library instrumentation.

The fresh Eigen build used exact 4.10.0 source, CMake/Ninja Release,
`BUILD_LIST=core,imgproc`, tests/perf/examples/apps off, IPP/OpenCL/ITT/
LAPACK off, `WITH_EIGEN=ON`, explicit `EIGEN_INCLUDE_PATH`, empty
`CPU_DISPATCH`, `CMAKE_CXX_FLAGS='-frounding-math -fno-fast-math'`.
`cvconfig.h` defines `HAVE_EIGEN`; build information reports 3.4.0.
The locally extracted Debian `libeigen3-dev_3.4.0-5_all.deb` SHA-256 is
`123ff96e6929713b852f58a53727379149fc4a2b682bd04605e784f6620ac08e`.
It was not installed system-wide and is not a crate dependency.

The fresh Eigen sanitizer build used the same source/features and Debug.
Both C and C++ received `-O1 -g -fsanitize=address,undefined
-fno-omit-frame-pointer`; C++ also received `-frounding-math
-fno-fast-math`. Shared linker flags were `-fsanitize=address,undefined`.

Verbatim selected result lines from the final probe (4.14 Jacobi and
fresh 4.10 Eigen+ASan/UBSan, respectively):

```text
case=sum_overflow exponent=63 rounding=0 finite=1 norm2=0x1p+0 invalid=1 divzero=0 overflow=1 underflow=0 line=0x0p+0,0x0p+0,0x1p+0,0x0p+0,0x0p+0,0x0p+0,
case=sum_overflow exponent=63 rounding=3072 finite=1 norm2=0x1.fffffecba6e4p-1 invalid=0 divzero=0 overflow=1 underflow=0 line=0x1.279a72p-1,0x1.279a78p-1,0x1.279a72p-1,0x0p+0,0x0p+0,0x0p+0,
```

On this Linux environment rounding constants 0/1024/2048/3072 denote
nearest/downward/upward/toward-zero. Interpret names rather than assuming
these numeric encodings on another platform. Final probe source SHA-256:
`faed9485b05c4bfdf9be9fc87496767833031df91da6397600bb4f0d35aa4945`.

## Regression checks and review boundary

- `alr -n build`: passed, native **4.10.0 / imgproc**.
- `alr -n -C tests run`: **542 registered/executed/successful**,
  zero failed assertions or unexpected errors.
- Validation profile build and full run: **542/542**.
- Restored `--profiles=opencv_geometry=release` and full run: **542/542**.
- Existing research runner self-test: **8 tests passed**.
- `git diff --check`: passed.
- No Ada or proof-scoped code changed: GNATformat/GNATprove not applicable.
  No new AUnit or malformed-C-ABI tests because no new API/ABI exists.
- Production shim unchanged. **No public semantic validation is duplicated
  in the C++ shim.** The new executable is explicitly research-only and
  is excluded from default native tests and Alire builds.

To reopen implementation: derive and independently review the missing
L2-only envelope, specify supported backend/version/environment premises,
qualify integer conversion separately if wanted, and test the resulting
domain. Do not repeat robust RNG experiments or treat the observations
here as a proof. Robust 3D distance metrics remain separately deferred.