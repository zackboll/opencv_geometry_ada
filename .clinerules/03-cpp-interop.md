# C++ Shim and ABI Rules

Module boundaries, native backends, and platform C++ isolation are in
`.clinerules/01-architecture.md`. Public Ada design is in
`.clinerules/02-ada-design.md`. This file covers the Geometry C ABI and
shim.

## Stable C ABI

All communication between Ada and OpenCV C++ must cross a C-compatible
ABI. Export shim functions with `extern "C"`.

Never expose across the boundary:

- C++ references, exceptions, templates, or name-mangled symbols
- STL containers, including `std::string` and `std::vector`
- `cv::Mat`, `cv::Point`, `cv::Moments`, or other OpenCV classes
- Core Mat handles or any Core module-bridge type

Keep the ABI simple, explicit, and mechanically bindable from Ada.

## ABI-safe types

Use C-compatible types:

- fixed-width integers from `<stdint.h>`
- `float` and `double`
- plain C structs whose layout is intentionally part of the ABI
- explicit pointer + count pairs for point buffers
- fixed-width integer status values and 0/1 selectors

Do not expose C++ `bool`, C++ enums, references, STL types, bitfields,
or overloaded C++ signatures.

Geometry currently uses:

- `opencv_geometry_point_i32` for packed contour points
- `opencv_geometry_moments` for the 24 moment fields
- `int32_t` point counts and 0/1 selectors
- `double` scalar outputs

Do not assume Ada `Integer` or `Natural` match C integer width. All
representation conversions belong in the thin Ada interoperability
layer.

This crate does not currently use opaque C++ object handles. Do not add
Mat handles, Core module-bridge includes, or a destroy/finalization
protocol unless an architectural decision introduces a Geometry-owned
C++ object.

## C ABI naming

Prefix every exported Geometry shim symbol with `opencv_geometry_`.
Use lowercase `snake_case`. Each exported function must have one
unambiguous C ABI signature.

Existing examples:

```c
opencv_geometry_last_error_message
opencv_geometry_contour_area
opencv_geometry_arc_length
opencv_geometry_contour_moments
```

Do not export short generic names such as `clone` or `destroy`. Do not
add image-processing symbols such as `opencv_geometry_cvt_color`.

## Point buffers and variable-length results

Geometry inputs and outputs are C-compatible point buffers, not Mat
handles.

Pack and unpack X/Y explicitly. Copy in Ada array iteration order.
Check the count range before indexing. Never reinterpret public Ada
point storage as C records.

STL containers may exist only inside the shim. They must never cross
the C ABI. Borrowed pointers to temporary C++ storage must never
escape the shim.

Do not return `new`/`malloc` allocated arrays that require Ada callers
to use C++ ownership rules.

Prefer caller-provided buffers:

- Ada allocates a C-compatible output array
- the ABI receives pointer, capacity, and an output count
- the shim writes at most `capacity` points and returns the count
- Ada constructs the public result from that count

When a safe mathematical upper bound is known from the input, allocate
that capacity on the Ada side rather than inventing a separate C++
allocation protocol.

Preserve iteration order. Handle empty input without indexing.

Copy all 24 moments fields explicitly. Do not `memcpy` a C++
`cv::Moments` object across the ABI.

## Diagnostics and status

Do not transfer ownership of C++ strings across the ABI. Diagnostic
storage is thread-local and owned by the shim.

```c
const char *opencv_geometry_last_error_message(void);
```

The returned pointer is borrowed. Ada must not free it. It is valid
only until a later shim call on the same thread changes the error
state. The thin Ada layer must copy the message into an Ada-owned
string before higher layers use it.

Never require Ada to call C++ allocation or deallocation routines.

Functions that can fail return `opencv_geometry_status` and place
successful results in output parameters. Status constants are:

- `OPENCV_GEOMETRY_OK`
- `OPENCV_GEOMETRY_ERROR_OPENCV`
- `OPENCV_GEOMETRY_ERROR_STD`
- `OPENCV_GEOMETRY_ERROR_UNKNOWN`
- `OPENCV_GEOMETRY_ERROR_INVALID_ARGUMENT`

On success, return `OPENCV_GEOMETRY_OK` after initializing required
outputs. On failure, return a nonzero status, leave outputs in a known
safe state, and preserve a useful diagnostic. Initialize outputs to
safe values before any operation that may throw.

Status values are part of the published C ABI and must remain stable
once released.

## Exception containment

Every exported shim function that can throw must catch C++ exceptions
before leaving `extern "C"`.

```cpp
try {
    /* OpenCV operation */
} catch (const cv::Exception& e) {
    /* preserve diagnostic and return OPENCV_GEOMETRY_ERROR_OPENCV */
} catch (const std::exception& e) {
    /* preserve diagnostic and return OPENCV_GEOMETRY_ERROR_STD */
} catch (...) {
    /* preserve diagnostic and return OPENCV_GEOMETRY_ERROR_UNKNOWN */
}
```

Catch more specific exceptions first. Cleanup paths exposed through
the C ABI must not throw. Ada must never depend on the C++ unwinder
crossing the ABI.

Native failures become `OpenCV.OpenCV_Error` through a private Ada
helper. Do not expose shim status codes in the public Ada API.

## Native OpenCV calls

The shim calls the authoritative OpenCV implementation. Select headers
and native libraries as required by `.clinerules/01-architecture.md`.

The shim may contain version-specific native compatibility handling
when OpenCV 4 and OpenCV 5 declarations differ. It must not paper over
those differences by depending on Ada Imgproc or Core's C++ shim.

Do not reimplement Geometry algorithms in the shim. Call OpenCV.

## Argument validation

Thick Ada is the single source of truth for public semantic policy.
The shim must not reimplement that policy for defense in depth,
identical diagnostics, or friendlier messages.

The shim still protects the ABI. It must not blindly dereference null
output pointers, null point buffers with a positive count, or other
pointer/count combinations that would cause undefined behavior.

A typical result-producing Geometry shim function should:

1. clear the thread-local error state
2. initialize every output parameter to a safe value
3. reject null outputs and unsafe pointer/count combinations
4. reject any other condition required to prevent undefined behavior
5. call OpenCV
6. publish outputs only after success
7. translate C++ exceptions into the C status model

Distinguish:

1. Ada-level programmer errors, normally caught before the ABI
2. invalid ABI arguments, which return an explicit shim status
3. valid inputs rejected by OpenCV, which preserve the OpenCV
   diagnostic

Do not duplicate semantic validation in both Ada and C++ unless it is
required for safety.

If a semantic-looking C++ check must remain because bypassing it would
be unsafe, document it with:

    // ABI safety: <specific reason this cannot safely be Ada-only>

Acceptable reasons include:

- OpenCV does not validate this condition before raw pointer access
- violating this condition can cause out-of-bounds access
- OpenCV accepts this representation but leaves part of the result
  uninitialized
- the shim itself performs pointer arithmetic that requires this
  invariant
- OpenCV performs signed integer arithmetic on counts before it
  validates the result, so overflow must be rejected at the ABI

"OpenCV might reject this" is not sufficient justification.

A raw C ABI caller is not entitled to the complete public Ada contract.
OpenCV should normally be allowed to reject invalid semantic input that
reaches the shim when doing so is safe.

Do not add postcondition checks that merely restate documented OpenCV
behavior unless they protect ownership, memory, or ABI safety.
