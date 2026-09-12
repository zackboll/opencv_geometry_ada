# Geometry tests

The separate tests Alire crate owns AUnit, GNATprove and GNATcov dependencies.
Never add development-only dependencies to the production crate.
Use focused Contour_Geometry_Tests and Contour_Moments_Tests suites.
Test ordinary, oriented, translated, degenerate and nonzero-bound contours.
Use tolerance-based comparisons for moments.

Malformed ABI tests must call OpenCV.Geometry.Internal.C_API, never redeclare
imports. Check invalid counts, pointer combinations, selectors and useful
diagnostics, plus complete zero moments on empty input and failure.
Do not migrate Find_Contours integration tests or depend on Ada Imgproc.

Run alr -n build, alr -n -C tests run and git diff --check. Report the actual
registered AUnit test count and native OpenCV version/backend. Keep compiler
warnings as errors and Ada lines within 79 columns.
