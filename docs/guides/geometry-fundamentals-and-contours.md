# Geometry fundamentals and contour analysis

This guide introduces the point types of `OpenCV.Geometry` and the
measurements made on a single contour: area, length, moments, hulls and
convexity defects, curve approximation, bounding boxes, point location and
shape matching. The public Ada specifications are authoritative: if this
guide or the README disagrees with a declaration's documentation in the API
reference, the specification is right.

## Point sets and coordinates

A [Contour](api:Contour) is an `OpenCV.Point_Array` of integer points, which
OpenCV receives as `CV_32S` in index order. A
[Float32_Point_Array](api:Float32_Point_Array) holds binary32 points and uses
OpenCV's `CV_32F` path, so subpixel coordinates are never rounded. Most
operations have one overload of each.

- Inputs may have any bounds; points are read in index order.
- Array results are zero-based, or the null range `1 .. 0` when empty, unless
  the declaration says otherwise; a few, such as
  [Closest_Ellipse_Points](api:Closest_Ellipse_Points), keep the bounds of
  their input.
- Every Float32 coordinate must be finite. Many Float32 overloads also limit
  coordinate spans so that OpenCV's binary32 differences cannot overflow; each
  declaration states its own limits.
- Orientation follows OpenCV: X increases to the right and Y upward. Image
  coordinates usually point Y downward, so a winding can look reversed on
  screen.
- Inputs are never modified, and results are Ada-owned values that refer to
  no native storage; the one exception in `OpenCV.Geometry` is the rotation
  matrix, an `OpenCV.Core.Mat`.

## Area, length and moments

[Contour_Area](api:Contour_Area) returns the polygon area, as an absolute
value unless `Oriented` asks for OpenCV's signed area.
[Arc_Length](api:Arc_Length) sums the segment lengths, including the closing
segment when `Closed` is True. The [Float32 Arc_Length](api:Arc_Length/2)
computes each segment in binary32, so a segment longer than about 1.8E+19
overflows and raises `OpenCV.OpenCV_Error`.

[Compute_Moments](api:Compute_Moments) returns all 24 fields of OpenCV's
moments in a [Moments_Result](api:Moments_Result): spatial, central and
normalized central moments through third order. For an ordinary simple
contour `M_00` is its area and the centroid is `(M_10 / M_00, M_01 / M_00)`;
check `M_00 = 0.0` before dividing. [Hu_Moments](api:Hu_Moments) turns moments
into the seven Hu invariants.

## Hulls, defects and convexity

[Convex_Hull](api:Convex_Hull) returns hull points and
[Convex_Hull_Indices](api:Convex_Hull_Indices) their indices in the input's own
range, so shifted bounds are preserved. Both take a
[Hull_Orientation](api:Hull_Orientation).

[Convexity_Defects](api:Convexity_Defects) measures how far a contour departs
inward from each hull edge. The [one-argument overload](api:Convexity_Defects/2)
computes the hull itself; the [two-argument overload](api:Convexity_Defects/1)
accepts strictly monotonic hull indices. Depths are multiples of 1/256, the
resolution OpenCV stores them with.

[Is_Convex](api:Is_Convex) expects a simple contour: OpenCV leaves the
result for self-intersecting contours undefined.
[Approximate_Curve](api:Approximate_Curve) runs Douglas-Peucker with a maximum
deviation `Epsilon`; OpenCV 4.x measures distances to the line through a
chord and OpenCV 5.x to the chord itself, so the two can keep different
vertices.

## Bounding boxes, location and matching

[Bounding_Rect](api:Bounding_Rect) returns an upright `OpenCV.Rect`. For
integer points its extent is inclusive, `Width = X_Max - X_Min + 1`; the
[Float32 overload](api:Bounding_Rect/2) applies the same formula to the
floors of the extreme coordinates.
[Locate_Point](api:Locate_Point) classifies a query as inside, outside or on
the boundary, and [Signed_Distance_To_Contour](api:Signed_Distance_To_Contour)
returns the signed distance to the nearest edge (positive inside). For a
nonempty contour OpenCV rounds the query to a signed 32-bit point, so each
query coordinate must be at least `-2.0**31` and less than `2.0**31`.

[Match_Shapes](api:Match_Shapes) compares two contours through their Hu
invariants with one of the three [Shape_Match_Method](api:Shape_Match_Method)
formulas; lower scores mean more similar shapes, and the relative method uses
the left contour as reference.

## Example

The example measures an L-shaped contour. The values it asserts are exact or
follow from the geometry; it never relies on a native vertex order.

```ada
with OpenCV;
with OpenCV.Geometry;

--  Measures an L-shaped integer contour: area, length, moments, convexity,
--  hull, defects, approximation, bounding box, point location and matching.

procedure Contours_And_Moments is
   use OpenCV.Geometry;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Rect;

   --  Counterclockwise in OpenCV's convention (X right, Y up).
   Shape   : constant Contour :=
     [(X => 0, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 1),
      (X => 1, Y => 1),
      (X => 1, Y => 3),
      (X => 0, Y => 3)];
   Moments : constant Moments_Result := Compute_Moments (Shape);
   Hull    : constant Contour := Convex_Hull (Shape);
   Indices : constant Point_Index_Array := Convex_Hull_Indices (Shape);
   Defects : constant Convexity_Defect_Array := Convexity_Defects (Shape);
   Box     : constant OpenCV.Rect := Bounding_Rect (Shape);

   --  The same square outline with redundant midpoints on every side.
   Dense   : constant Contour :=
     [(X => 0, Y => 0),
      (X => 2, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 2),
      (X => 4, Y => 4),
      (X => 2, Y => 4),
      (X => 0, Y => 4),
      (X => 0, Y => 2)];
   Corners : constant Contour :=
     Approximate_Curve (Dense, Epsilon => 0.5, Closed => True);

   --  Shape moved by (10, 20): matching is translation invariant.
   Moved : Contour (Shape'Range);
begin
   pragma Assert (Contour_Area (Shape) = 6.0);
   pragma Assert (Arc_Length (Shape, Closed => True) = 14.0);
   pragma Assert (Moments.M_00 = 6.0);
   --  Centroid (M_10 / M_00, M_01 / M_00) of the two rectangles.
   pragma Assert (abs (Moments.M_10 / Moments.M_00 - 1.5) < 1.0E-12);
   pragma Assert (abs (Moments.M_01 / Moments.M_00 - 1.0) < 1.0E-12);

   pragma Assert (not Is_Convex (Shape));
   --  The concave vertex (1, 1) is not on the hull.
   pragma Assert (Hull'Length = 5 and then Hull'First = 0);
   pragma Assert (Indices'Length = Hull'Length);
   pragma Assert (for all Index of Indices => Index in Shape'Range);
   --  The notch at (1, 1), index 3 of Shape, is the deepest defect.
   pragma
     Assert
       (for some Defect of Defects =>
          Defect.Farthest_Index = 3 and then Defect.Depth in 1.6 .. 1.7);

   --  Inclusive integer extent: Width = 4 - 0 + 1, Height = 3 - 0 + 1.
   pragma Assert (Box = (X => 0, Y => 0, Width => 5, Height => 4));
   pragma Assert (Corners'Length = 4);

   pragma Assert (Locate_Point (Shape, (X => 0.5, Y => 2.0)) = Inside_Contour);
   pragma
     Assert (Locate_Point (Shape, (X => 2.0, Y => 0.0)) = On_Contour_Boundary);
   pragma
     Assert (Locate_Point (Shape, (X => 2.0, Y => 2.0)) = Outside_Contour);
   pragma
     Assert
       (abs (Signed_Distance_To_Contour (Shape, (X => 2.0, Y => 2.0)) + 1.0)
          < 1.0E-9);

   for Index in Shape'Range loop
      Moved (Index) := (X => Shape (Index).X + 10, Y => Shape (Index).Y + 20);
   end loop;
   pragma Assert (Match_Shapes (Shape, Moved, Log_Difference) < 1.0E-9);
end Contours_And_Moments;
```

## Interpreting results

- Compare floating-point results with tolerances, except where the geometry
  makes them exact, as for small integer contours.
- Hull and approximation results may start at different vertices on
  different OpenCV releases; compare them as sets or by length.
- Rejected input and native failures raise `OpenCV.OpenCV_Error`; the
  binding never returns a partial result.
- The [shape fitting guide](shape-fitting-and-intersections.md) continues
  with fitted and enclosing shapes, and the
  [compatibility guide](compatibility-ownership-and-safety.md) explains the
  version differences mentioned here.
