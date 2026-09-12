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
