# Affine and perspective geometry

This guide covers the transforms of `OpenCV.Geometry`: computing affine and
perspective transforms from point correspondences, inverting them, mapping
points, and building rotation matrices. The public Ada specifications are
authoritative: if this guide or the README disagrees with a declaration's
documentation in the API reference, the specification is right.

## Transform values

An [Affine_Transform_2D](api:Affine_Transform_2D) is a 2 x 3 array and a
[Perspective_Transform_2D](api:Perspective_Transform_2D) a 3 x 3 array of
binary64 coefficients. Both are ordinary Ada values that the caller owns and
copies freely. Indices start at 1, so `T (R, C)` is OpenCV's
`M (R - 1, C - 1)`: an affine transform maps `(X, Y)` to
`(T (1, 1) * X + T (1, 2) * Y + T (1, 3), T (2, 1) * X + T (2, 2) * Y + T (2, 3))`.
`Identity_Affine_Transform` and `Identity_Perspective_Transform` map every
point to itself.

## Transforms from correspondences

[Get_Affine_Transform](api:Get_Affine_Transform) takes exactly three Source
and three Destination points, paired in iteration order, and returns the
transform that maps one triangle onto the other.
[Invert_Affine_Transform](api:Invert_Affine_Transform) returns its inverse.
Both follow OpenCV in returning the all-zero transform, not an error, when
the system is singular, as for collinear Source points; check the Source
triangle when you need a nondegenerate mapping.

[Get_Perspective_Transform](api:Get_Perspective_Transform) takes exactly four
correspondences and a [Perspective_Solve_Method](api:Perspective_Solve_Method).
OpenCV solves for eight coefficients with `T (3, 3)` fixed at 1.0. OpenCV
4.12 and later keep that solution only when the solver succeeds with a small
residual; otherwise, as for degenerate correspondences, they return a
least-squares solution with unit norm and arbitrary sign, whose `T (3, 3)`
need not be 1.0. A homography and any nonzero multiple of it map points
identically, so compare mapped points rather than coefficients.

## Mapping points

[Transform_Point](api:Transform_Point) and
[Transform_Points](api:Transform_Points) map points with Ada arithmetic, not
a native call: each coordinate is evaluated in binary64 and rounded to
binary32. Points must be finite and coefficients finite with magnitude at
most 1.0E+269; within those limits SPARK proves that no binary64
intermediate overflows.

- The [perspective overload](api:Transform_Point/2) divides by every nonzero
  `W` and raises `OpenCV.OpenCV_Error` for `W = 0.0`, whereas
  `cv::perspectiveTransform` maps a point with a tiny `W` to the origin.
- [Transform_Points](api:Transform_Points) keeps the bounds and order of its
  input, and raises without a partial result if any point fails.

## Rotation matrices

[Get_Rotation_Matrix_2D](api:Get_Rotation_Matrix_2D) returns a new 2 x 3
binary64 `OpenCV.Core.Mat`, ready for an affine image warp such as
`OpenCV.Image_Processing.Warp_Affine` in the Imgproc binding. The Mat has
ordinary Core lifetime, and its coefficients can be read with
`OpenCV.Core.Float64_Access`. The angle is in degrees by default or radians
on request, and is reduced modulo a full turn in either unit. Positive
angles turn counterclockwise as seen on an image whose origin is the
top-left corner, with Y pointing down.

## Typed Mat interchange and composition

[To_Mat](api:To_Mat) allocates an independent Core-owned Float64 C1 Mat:
2x3 for affine, 3x3 for perspective. Transform `(R, C)` maps directly to
Mat `(R - 1, C - 1)`. [Affine_From_Mat](api:Affine_From_Mat) and
[Perspective_From_Mat](api:Perspective_From_Mat) require exactly that shape,
two dimensions, Float64 depth and one channel. Empty/default Mats, Float32,
NaN and either infinity are rejected with `OpenCV.OpenCV_Error`. Checked
typed access supports non-contiguous Regions without assuming row layout.
The result is an Ada-owned copy, unaffected by source mutation, rebinding or
finalization. Each conversion back to Mat allocates again; later ordinary Mat
assignment still shares storage according to Core's existing semantics.
These helpers require no Core version beyond the existing 0.5.0 floor.

[Get_Rotation_Affine_Transform_2D](api:Get_Rotation_Affine_Transform_2D)
returns the same rotation as the Mat operation, as an Ada value. It preserves
degree/radian full-turn reduction, center invariance, image-coordinate sign,
and finite zero/negative scale support; it does not duplicate native rotation.

[Compose](api:Compose) means **apply First, then Second**, hence
`Second * First` for column vectors. Affine composition uses the implicit
last row `(0, 0, 1)`; perspective composition multiplies all nine coefficients.
It never normalizes `(3, 3)`, including native OpenCV 4.12+/5.x homographies.
All input coefficients are validated, and binary64 multiplication and
left-to-right addition are checked **before** evaluation. Each product and
absolute-operand sum must fit a conservative `1.0E+300` budget. Cancellation
does not rescue a rejected partial sum. This intentionally rejects some
representable results with excessively large intermediates. Rounding and
gradual underflow follow binary64 arithmetic; there is no saturation or
clamping. Existing point-mapping bounds are unchanged.

## Numerically guarded perspective inversion

[Invert_Perspective_Transform](api:Invert_Perspective_Transform) uses public
Core LU inversion, reading its discriminated `Inverse` only after checking
`Invertible`. It rejects singular/unsafe results, never an all-zero placeholder.
The existing affine inverse's native singular-to-zero semantics are unchanged.

The numerical envelope is deliberately conservative:

1. All inputs are finite. Set `S = max abs H(R,C)`, requiring
   `1.0E-280 <= S <= 1.0E+280`, and temporarily form `B = H / S`.
2. Each nonzero normalized coefficient must have magnitude at least
   `1.0E-100`; require `abs det B >= 1.0E-12` before native inversion.
   This bounds direct 3x3 determinant/cofactor/reciprocal arithmetic; it is
   **not** an absolute determinant test on the arbitrarily scaled homography.
   With entries bounded by one, products are at most one, minors at most two
   and determinant partial sums at most six. Fewer than 32 binary64 roundings
   contribute much less than `1.0E-13` absolute uncertainty, so the floor
   also leaves margin for differing Ada/native contraction or reassociation.
3. Require finite native inverse coefficients and the scale-independent
   infinity-norm condition estimate `||B||inf * ||inverse B||inf <= 1.0E+8`.
4. Independently evaluate **both** `B * inverse B` and `inverse B * B` in
   guarded binary64 arithmetic. Each identity coefficient residual must be
   at most `1.0E-10` (an absolute coefficient error, not a condition-scaled
   tolerance that could conceal inaccurate inverses).
5. Divide the inverse by `S`, preserving the inverse of the original matrix,
   with no `(3, 3)` normalization. Reject rescaling overflow risk and any
   nonzero inverse coefficient below binary64's smallest normal value.
   Require both original-scale identity products to pass the same residual
   checks and arithmetic budget as well.

Well-conditioned matrices with very large/small common scale can therefore
pass, including negative scales and `(3, 3) /= 1`; ill-conditioned matrices,
extreme dynamic ranges, and unrepresentable inverses raise `OpenCV_Error`.
The gates establish measured residual/conditioning requirements, not exact
arithmetic or a guarantee for every invertible matrix. Point round trips
still incur binary32 rounding and must avoid singular denominators.

## Example

The example builds a scale-and-translate transform from three
correspondences, inverts it, maps a batch with shifted bounds, solves a
homography, and reads a rotation matrix through Core.

```ada
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Geometry;

--  Builds affine and perspective transforms from correspondences, maps and
--  inverts points, and inspects a rotation matrix returned as a Core Mat.

procedure Affine_And_Perspective is
   use OpenCV.Geometry;
   use type OpenCV.Float32_Point;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;

   function Near (Left, Right, Tolerance : OpenCV.Float64_Value) return Boolean
   is (abs (Left - Right) <= Tolerance);

   --  Scale X by 2 and Y by 3, then translate by (10, 20).
   Affine   : constant Affine_Transform_2D :=
     Get_Affine_Transform
       (Source      =>
          [(X => 0.0, Y => 0.0), (X => 1.0, Y => 0.0), (X => 0.0, Y => 1.0)],
        Destination =>
          [(X => 10.0, Y => 20.0),
           (X => 12.0, Y => 20.0),
           (X => 10.0, Y => 23.0)]);
   Inverse  : constant Affine_Transform_2D := Invert_Affine_Transform (Affine);
   Mapped   : constant OpenCV.Float32_Point :=
     Transform_Point (Affine, (X => 1.0, Y => 1.0));
   Restored : constant OpenCV.Float32_Point :=
     Transform_Point (Inverse, Mapped);

   --  A batch keeps the bounds of its input, here 5 .. 6.
   Batch   : constant Float32_Point_Array (5 .. 6) :=
     [(X => 0.0, Y => 0.0), (X => 2.0, Y => 1.0)];
   Results : constant Float32_Point_Array := Transform_Points (Affine, Batch);

   --  The unit square onto a trapezoid.
   Homography : constant Perspective_Transform_2D :=
     Get_Perspective_Transform
       (Source      =>
          [(X => 0.0, Y => 0.0),
           (X => 1.0, Y => 0.0),
           (X => 1.0, Y => 1.0),
           (X => 0.0, Y => 1.0)],
        Destination =>
          [(X => 0.0, Y => 0.0),
           (X => 4.0, Y => 0.0),
           (X => 3.0, Y => 2.0),
           (X => 1.0, Y => 2.0)]);
   Corner     : constant OpenCV.Float32_Point :=
     Transform_Point (Homography, (X => 1.0, Y => 1.0));

   --  A 90 degree rotation about the origin, as a 2 x 3 Float64 Mat.
   Rotation           : constant OpenCV.Core.Mat :=
     Get_Rotation_Matrix_2D (Center => (X => 0.0, Y => 0.0), Angle => 90.0);
   Rotation_Value     : constant Affine_Transform_2D :=
     Get_Rotation_Affine_Transform_2D ((0.0, 0.0), 90.0);
   --  Apply rotation first, then the scale-and-translate mapping.
   Combined           : constant Affine_Transform_2D :=
     Compose (Rotation_Value, Affine);
   Warp_Matrix        : constant OpenCV.Core.Mat := To_Mat (Combined);
   Homography_Inverse : constant Perspective_Transform_2D :=
     Invert_Perspective_Transform (Homography);
   Identity           : constant Perspective_Transform_2D :=
     Compose (Homography, Homography_Inverse);
begin
   pragma Assert (Affine_From_Mat (Rotation) = Rotation_Value);
   pragma Assert (Affine_From_Mat (Warp_Matrix) = Combined);
   pragma Assert (Perspective_From_Mat (To_Mat (Homography)) = Homography);
   for R in Identity'Range (1) loop
      for C in Identity'Range (2) loop
         pragma
           Assert
             (Near
                (Identity (R, C),
                 Identity_Perspective_Transform (R, C),
                 1.0E-10));
      end loop;
   end loop;
   pragma Assert (Near (Affine (1, 1), 2.0, 1.0E-9));
   pragma Assert (Near (Affine (2, 2), 3.0, 1.0E-9));
   pragma Assert (Near (Affine (1, 3), 10.0, 1.0E-9));
   pragma Assert (Near (Affine (2, 3), 20.0, 1.0E-9));
   pragma Assert (Near (Affine (1, 2), 0.0, 1.0E-9));
   pragma Assert (Mapped = (X => 12.0, Y => 23.0));
   pragma Assert (abs (Restored.X - 1.0) < 1.0E-5);
   pragma Assert (abs (Restored.Y - 1.0) < 1.0E-5);

   pragma Assert (Results'First = 5 and then Results'Last = 6);
   pragma Assert (Results (5) = (X => 10.0, Y => 20.0));
   pragma Assert (Results (6) = (X => 14.0, Y => 23.0));

   --  The mapping holds whatever overall scale OpenCV gives the solution.
   pragma Assert (abs (Corner.X - 3.0) < 1.0E-4);
   pragma Assert (abs (Corner.Y - 2.0) < 1.0E-4);

   pragma
     Assert
       (OpenCV.Core.Rows (Rotation) = 2
          and then OpenCV.Core.Columns (Rotation) = 3);
   pragma
     Assert
       (Near (OpenCV.Core.Float64_Access.Get (Rotation, 0, 0), 0.0, 1.0E-12));
   pragma
     Assert
       (Near (OpenCV.Core.Float64_Access.Get (Rotation, 0, 1), 1.0, 1.0E-12));
   pragma
     Assert
       (Near (OpenCV.Core.Float64_Access.Get (Rotation, 1, 0), -1.0, 1.0E-12));
end Affine_And_Perspective;
```

## Interpreting results

- Transforms computed by OpenCV are native binary64 coefficients, returned
  without normalization; compare them with tolerances.
- Mapped points are rounded to binary32, so exact equality holds only when
  the true result is representable, as in the example's small integers.
- Core's `Mat` row and column indices start at 0, while transform arrays
  start at 1.
- The [compatibility guide](compatibility-ownership-and-safety.md) explains
  ownership of the `Mat` returned here and the error model shared by every
  operation.
