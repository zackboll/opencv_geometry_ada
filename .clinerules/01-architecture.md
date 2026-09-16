# Geometry architecture

This crate implements only `OpenCV.Geometry`. Geometry is deliberately
smaller than Core or Imgproc: Ada-owned point collections and value
records, no Mat module bridge, and no Core C++ shim.

## Production dependencies

The only intended production Ada dependency is `opencv_core`.

Do not add an Ada dependency on `opencv_imgproc`, `opencv_imgcodecs`,
`opencv_highgui`, `opencv_videoio`, or any other OpenCV module crate.

Native OpenCV library linkage is not an Ada crate dependency.

OpenCV 4 implements Geometry operations in native `imgproc`. That is a
backend detail below the public Ada package. It does not authorize an
Ada Imgproc dependency, Imgproc APIs, or image-processing
responsibilities in this crate.

Do not migrate `Find_Contours`, color conversion, filtering, drawing, or
other image-processing operations into Geometry.

Do not introduce a Core Mat module bridge, borrow Mat handles, or link
`libopencv_core_shim`. Reusing a public root OpenCV value type is allowed.
Taking a dependency on Core's C++ objects or shim is not.

`OpenCV` owns the shared public value types such as `Point`,
`Point_Array`, `Size`, `Rect`, `Scalar`, and `Float64_Value`. The
`opencv_core` crate still distributes the parent package. Geometry may
reuse those types. Geometry must not redeclare them. `OpenCV.Core` owns
`Mat` and matrix-specific abstractions.

## Layering

Bindings flow downward only:

thick Ada -> thin Ada C interop -> C ABI -> C++ shim -> native OpenCV

Lower layers must never depend on higher layers. The public Ada API must
never import C shim symbols or depend on C++ ABI details.

Public Ada design belongs in `.clinerules/02-ada-design.md`. ABI and
shim rules belong in `.clinerules/03-cpp-interop.md`.

## Native backend

Select headers by `CV_VERSION_MAJOR` and native libraries from the
configured OpenCV:

- OpenCV 4.x: `opencv2/imgproc.hpp` and `libopencv_imgproc`
- OpenCV 5.x: `opencv2/geometry.hpp` and `libopencv_geometry`

Both also link native `libopencv_core`. The public Ada package remains
`OpenCV.Geometry` on every supported OpenCV version.

Linux OpenCV 4 therefore links native `imgproc`. That is the correct
backend, not an Ada Imgproc dependency. OpenCV 5 shims must not pick up
`libopencv_imgproc` merely because OpenCV 4 used that native library.

Future major versions, including OpenCV 6+, are unsupported until
deliberately evaluated. Changing native backend selection or extending
the supported major-version range is an architectural decision. See
`.clinerules/06-agent-workflow.md`.

## Platform C++ isolation

The platform-specific Geometry shim strategy is intentional
architecture, not incidental build configuration.

- Linux may use GNU g++, libstdc++, and the existing static-PIC shim
  compiled through GPRbuild.
- macOS Geometry C++ is built outside GPRbuild with Apple `clang++`.
  It must use `libc++`, not the GNAT-bundled C++ runtime. The dylib
  remains independently relocatable with install name
  `@rpath/libopencv_geometry_shim.dylib`. Ada consumers need a runtime
  rpath to this crate's `lib` directory; `-L` is link-time only.
- Windows Geometry C++ is built outside GPRbuild with the MSYS2/MinGW
  toolchain from the same prefix as the installed OpenCV. Do not
  silently fall back to GNAT's bundled `g++`.
- External relocatable shims exist so Geometry cannot inherit Core's
  relocatable Ada C++ shim through the GPR project closure.
- Geometry must not acquire a dependency on `libopencv_core_shim`.

Do not "simplify" these strategies into a unified C++ compiler, runtime,
or linkage path without an explicit architectural decision from the
user.

Changing the established C++ compiler, C++ runtime, static versus
relocatable shim, or `@rpath` model is a significant architectural
decision. See `.clinerules/06-agent-workflow.md`.

## Contour storage

The public `Contour` is a subtype of `OpenCV.Point_Array`. Storage
is Ada-owned.

Pack X/Y explicitly into signed 32-bit C records in array iteration
order. Check the count range. Never reinterpret public point storage as
C records and never index an empty array. Copy all 24 moments fields
explicitly across both boundaries.

## Variable-length results

Public variable-length Geometry results should normally be Ada-owned
point collections.

Do not return STL containers, borrowed pointers to temporary C++
storage, or `new`/`malloc` arrays that force Ada callers to follow C++
ownership rules.

Prefer caller-provided C-compatible buffers with explicit capacity and a
returned count. When a safe mathematical upper bound is known from the
input, allocate that capacity on the Ada side rather than inventing a
separate C++ allocation protocol.

Preserve iteration order. Handle nonzero Ada array bounds correctly.

ABI mechanics belong in `.clinerules/03-cpp-interop.md`.

## Validation and errors

Ada owns public semantic policy. C++ validates ABI representations,
pointer/count safety, and output initialization, and contains every
exception. Native failures raise `OpenCV.OpenCV_Error` through a private
helper.

No STL, C++ exceptions, or native objects cross the C ABI.
