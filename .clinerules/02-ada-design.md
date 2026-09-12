# Ada API Design Rules

## Idiomatic Ada First

The public API must look and feel like native Ada.

Do not mechanically transliterate the OpenCV C++ API.

Preserve OpenCV Geometry semantics, capabilities, and expected
performance, but choose Ada constructs that best express those
semantics.

Prefer:

- strong Ada types over integer constants
- enumerations over magic values
- overloads where they improve readability
- default parameters where appropriate
- ranges and subtypes where they add useful constraints
- contracts for meaningful preconditions, postconditions, and invariants
- Ada exceptions for exceptional failures

Avoid exposing:

- C++ naming conventions
- raw pointers
- C-style status values
- implementation handles
- C++ template syntax
- STL concepts
- unnecessary `Interfaces.C` types

A user working only with the thick Ada layer should not need to
understand the C++ shim.

## Public package and types

Expose this crate under `OpenCV.Geometry`. Do not define a competing
root `OpenCV` package. Core owns `OpenCV` and `OpenCV.Core`.

Reuse public Core value types where they already exist: `Point`,
`Point_Array`, `Size`, `Rect`, `Scalar`, and `Float64_Value`.

Reusing a Core value type is not permission to use `OpenCV.Core.Mat`,
borrow Mat handles, or introduce a Core module bridge. Geometry
currently has no Mat API. Do not add one for convenience.

`OpenCV.Geometry` may define a public type only when Geometry requires
it and Core does not already supply it. `Contour` is a subtype of
`OpenCV.Core.Point_Array`. `Moments_Result` is a Geometry-owned value
record.

Keep Geometry types as ordinary Ada arrays and records unless a later
architectural decision introduces genuine object identity. Do not
manufacture tagged-type hierarchies, Mat subclasses, or Core-style
controlled wrappers.

Do not add `Find_Contours`, `CvtColor`, filtering, drawing, or other
image-processing operations to this crate. Those belong in Imgproc.

## Public naming

Use Ada-style names for Geometry operations:

- `Contour_Area`
- `Arc_Length`
- `Compute_Moments`

Prefer descriptive Ada names over terse C++ spellings. Do not expose
shim status codes, opaque handles, or `Interfaces.C` types in the
public API.

Keep raw interoperability under private children such as
`OpenCV.Geometry.Internal.C_API`. Public packages must not import C
shim functions directly.

## Variable-length results

Public variable-length Geometry results should normally be Ada-owned.

Typical results are contours or other point collections. Storage stays
in Ada arrays. Callers must not receive:

- STL containers
- borrowed pointers to temporary C++ storage
- `new`/`malloc` arrays that Ada would have to free with C++ rules

When a result length is not known until OpenCV returns, prefer a
caller-provided C-compatible buffer with explicit capacity and a
returned count. When a safe mathematical upper bound is known from the
input, allocate that capacity on the Ada side rather than inventing a
separate C++ allocation protocol.

Preserve OpenCV iteration order when packing and unpacking points.
Handle nonzero Ada array bounds. Never reinterpret a public
`Point_Array` as C records and never index an empty array.

Do not treat this as a mandate for one specific future operation. It
applies to any Geometry function that returns a variable-length point
collection.

ABI buffer mechanics belong in `.clinerules/03-cpp-interop.md`.

## Numeric representation

Keep C-compatible numeric types confined to the thin interoperability
layer.

The thin Ada binding may use `Interfaces.C` types and other exact
C-compatible representations required by the shim ABI.

The thick public Ada API should expose natural Ada numeric types and
Core/Geometry domain types. Do not leak `Interfaces.C` into the public
API merely because OpenCV is implemented in C++.

Perform explicit conversions at the thick/thin boundary. Avoid
unchecked or implicit narrowing. Use range checks, preconditions, or
explicit conversion helpers where conversion could lose information.

When exact ABI width matters, document and enforce it in the internal
layer.

## Ada versus C++ responsibility

Keep the C++ shim as small as practical.

Thick Ada owns:

- public semantic policy
- Ada range and type validation
- public API design
- conversion of public Core/Ada values to thin ABI representations
- translation of private status failures to Ada exceptions

Typical Ada work includes contour packing, count-range checks,
convenience overloads, and Geometry-specific value-type helpers that
do not require OpenCV itself.

The C++ shim owns ABI safety, native OpenCV calls, exception
containment, and version-specific native compatibility. Details are in
`.clinerules/03-cpp-interop.md`.

Do not turn the shim into a second high-level wrapper library.

Do not reimplement meaningful OpenCV algorithms in Ada merely to avoid
crossing the ABI boundary. If OpenCV already provides the operation,
the binding should normally call OpenCV.
