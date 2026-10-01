# Geometry tests

The separate tests Alire crate owns AUnit, GNATprove, and GNATcov
dependencies. Never add development-only dependencies to the production
crate.

Use focused Geometry suites such as `Contour_Geometry_Tests` and
`Contour_Moments_Tests`. Test ordinary, oriented, translated,
degenerate, empty, and nonzero-bound contours. Use tolerance-based
comparisons for moments.

When a Geometry operation returns a variable-length point collection,
cover iteration order, capacity/count behavior, empty input, and
nonzero Ada array bounds.

Malformed ABI tests must call `OpenCV.Geometry.Internal.C_API`, never
redeclare imports. Check invalid counts, pointer combinations,
selectors, useful diagnostics, and complete zero moments on empty
input and failure.

Do not add `Find_Contours`, color-conversion, or other Imgproc
integration tests. Do not depend on Ada Imgproc. Native OpenCV 4
`imgproc` linkage is a backend detail, not a test dependency.

Run `alr -n build`, `alr -n -C tests run`, and `git diff --check`.
Report the actual registered AUnit test count and native OpenCV
version/backend. Keep compiler warnings as errors and Ada lines within
79 columns.

Linux CI also runs the suite against the library built with
`alr -n -C tests build --profiles=opencv_geometry=validation`, which
enables every validity check and assertion. Code that passes, copies,
converts, or inspects values that may be Inf or NaN, whether caller input
or native results, must suppress validity checks locally
(`pragma Suppress (Validity_Check)`) so non-finite values raise
`OpenCV_Error` rather than `Constraint_Error`. The build profile persists
in the tests crate's Alire settings, and `alr -n -C tests run` reuses the
last one; rebuild with `--profiles=opencv_geometry=release` afterwards.

`tests/native` holds C++ tests for shim behavior that Ada cannot reach,
currently allocation-failure injection for the Subdiv2D handle: its
unusable state, and the failure behavior of its list and Voronoi queries.
They include the shim source and replace the global allocation
functions. Run them with `sh scripts/run_native_tests.sh` on Linux after
`alr -n build` whenever the Subdiv2D shim changes; Linux CI runs them
under AddressSanitizer and UndefinedBehaviorSanitizer.

Cross-platform CI runs Linux OpenCV 4 and macOS OpenCV 5 on pull requests
and pushes. Windows MSYS2 OpenCV 5 is intentionally a post-merge portability
check: its job runs only on pushes to `main` or manual `workflow_dispatch`,
not on pull requests or feature-branch pushes. Do not require a Windows PR
job to pass; confirm it is skipped by policy and retain its full build/tests
for main pushes and manual runs.
