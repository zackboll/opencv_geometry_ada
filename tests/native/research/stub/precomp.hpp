// Research-only stand-in for OpenCV's private precomp.hpp.
//
// scripts/run_min_enclosing_polygon_research.py copies an exact upstream
// min_enclosing_convex_polygon.cpp, unmodified, into a directory without
// OpenCV's own precomp.hpp and puts this directory on the include path, so
// that the file compiles against an installed OpenCV with sanitizers and
// library assertions. Only public headers are included.
#include "opencv2/core.hpp"
#include "opencv2/core/check.hpp"
#include "opencv2/core/utility.hpp"
#if CV_VERSION_MAJOR >= 5
#include "opencv2/geometry.hpp"
#else
#include "opencv2/imgproc.hpp"
#endif