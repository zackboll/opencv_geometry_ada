# Shape fitting and intersections

This guide covers the shapes `OpenCV.Geometry` fits to or wraps around a
point set, and the intersections of convex polygons and rotated rectangles.
The public Ada specifications are authoritative: if this guide or the README
disagrees with a declaration's documentation in the API reference, the
specification is right.

## Rotated rectangles

[Minimum_Area_Rectangle](api:Minimum_Area_Rectangle) returns OpenCV's
smallest-area rotated rectangle as an `OpenCV.Rotated_Rect`: a binary32
center, size and angle in degrees. OpenCV 4.13 and 5.x report angles in
`[-90, 0)` and assign width and height differently from 4.12 and earlier.
For an ordinary point set the region is the same, but `Width` need not name
the same physical side on every release.

[Box_Points](api:Box_Points) converts any rotated rectangle into its four
vertices, consecutive around the rectangle. The starting vertex is OpenCV's
and moves with the angle, so portable code compares the vertices as a set.

## Fitted ellipses

[Fit_Ellipse](api:Fit_Ellipse), [Fit_Ellipse_AMS](api:Fit_Ellipse_AMS) and
[Fit_Ellipse_Direct](api:Fit_Ellipse_Direct) fit an ellipse to at least five
points by least squares, Taubin's Approximate Mean Square method, and the
direct method of Fitzgibbon, Pilu and Fisher. Each returns the rotated
rectangle in which the ellipse is inscribed, so `Size` holds full axis
lengths, not radii. A fitted ellipse need not enclose the points.

When a system is singular, as for points exactly on one conic, OpenCV
perturbs the points and retries. OpenCV 4.12 and later draw that
perturbation from `cv::theRNG`, so such results need not repeat; the example
below avoids the case with points on two different circles.

## Fitted lines

[Fit_Line_2D](api:Fit_Line_2D) returns a [Fitted_Line_2D](api:Fitted_Line_2D):
a unit `Direction` and a `Point` on the line. The opposite direction
describes the same line, and the binding keeps OpenCV's sign.
[Line_Fit_Distance](api:Line_Fit_Distance) selects orthogonal least squares
(`L2`, the default, in closed form) or one of five robust M-estimators that
OpenCV solves iteratively. Robust fits repeat for the same input, but they
draw subsets by position, so reordering the points can change the result
slightly.

## Enclosing shapes

[Minimum_Enclosing_Circle](api:Minimum_Enclosing_Circle) returns an
[Enclosing_Circle](api:Enclosing_Circle). OpenCV adds a small EPS to every
radius, and it computes in binary32 from absolute coordinates, so a point
set far from the origin relative to its size can get a circle that misses a
point; the declaration gives a measured example.

[Minimum_Enclosing_Triangle](api:Minimum_Enclosing_Triangle) accepts integer
contours only. OpenCV's search has no iteration bound and can fail to return
for some nearly degenerate hulls, such as long thin quadrilaterals; the
binding cannot detect those inputs in advance. Use it on well-conditioned
hulls.

## Intersections

[Intersect_Convex_Polygons](api:Intersect_Convex_Polygons) intersects two
simple, strictly convex polygons of at least three vertices each and returns
a [Convex_Polygon_Intersection](api:Convex_Polygon_Intersection): the area
and the vertices, indexed `1 .. Vertex_Count`. Repeated or collinear
vertices raise `OpenCV.OpenCV_Error`, and coordinates must stay in the range
where OpenCV's binary32 arithmetic is exact, which the declaration states.
`Handle_Nested` decides whether a polygon strictly inside the other is the
result or gives an empty one.

The [Float32 overload](api:Intersect_Convex_Polygons/2) accepts only
coordinates on one binary grid, such as multiples of 0.25, because older
OpenCV releases can corrupt memory when their orientation tests round.
[Intersect_Convex_Polygons_Extended_Float32](api:Intersect_Convex_Polygons_Extended_Float32)
is the opt-in alternative for ordinary fractions such as 0.1: it runs a
private hardened copy of OpenCV's algorithm, with its own conditioning limit.

[Intersect_Rotated_Rectangles](api:Intersect_Rotated_Rectangles) returns a
[Rectangle_Intersection_Kind](api:Rectangle_Intersection_Kind) and at most
eight vertices. Rectangles that only touch can be reported with one or two
contact vertices.

## Example

The example fits and encloses small, well-conditioned point sets and
intersects two squares and two rectangles. It checks binary32 results with
tolerances and never depends on a native starting vertex.

```ada
with OpenCV;
with OpenCV.Geometry;

--  Fits and encloses well-conditioned point sets, then intersects convex
--  polygons and rotated rectangles. Checks use tolerances where OpenCV
--  computes in binary32, and never a native vertex order.

procedure Fitting_And_Intersections is
   use OpenCV.Geometry;
   use type OpenCV.Float32_Value;
   use type OpenCV.Point_Coordinate;

   function Near (Left, Right, Tolerance : OpenCV.Float32_Value) return Boolean
   is (abs (Left - Right) <= Tolerance);

   --  A 4 x 2 axis-aligned rectangle, possibly reported rotated by 90
   --  degrees, depending on the OpenCV release's angle convention.
   Corners   : constant Contour :=
     [(X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 2), (X => 0, Y => 2)];
   Rectangle : constant OpenCV.Rotated_Rect :=
     Minimum_Area_Rectangle (Corners);
   Vertices  : constant Box_Vertices := Box_Points (Rectangle);

   --  Eight points on two concentric circles around (5, 5), not on one
   --  conic, so the ellipse fit needs no random perturbation.
   Ring    : constant Contour :=
     [(X => 15, Y => 5),
      (X => 12, Y => 12),
      (X => 5, Y => 15),
      (X => -2, Y => 12),
      (X => -5, Y => 5),
      (X => -2, Y => -2),
      (X => 5, Y => -5),
      (X => 12, Y => -2)];
   Ellipse : constant OpenCV.Rotated_Rect := Fit_Ellipse (Ring);

   --  Overloaded operations need a qualified aggregate.
   Line   : constant Fitted_Line_2D :=
     Fit_Line_2D
       (Contour'
          [(X => 0, Y => 1),
           (X => 2, Y => 3),
           (X => 4, Y => 5),
           (X => 6, Y => 7)]);
   Circle : constant Enclosing_Circle :=
     Minimum_Enclosing_Circle
       (Contour'
          [(X => 0, Y => 0),
           (X => 4, Y => 0),
           (X => 4, Y => 4),
           (X => 0, Y => 4)]);

   Overlap  : constant Convex_Polygon_Intersection :=
     Intersect_Convex_Polygons
       (Left  =>
          Contour'
            [(X => 0, Y => 0),
             (X => 4, Y => 0),
             (X => 4, Y => 4),
             (X => 0, Y => 4)],
        Right =>
          Contour'
            [(X => 2, Y => 2),
             (X => 6, Y => 2),
             (X => 6, Y => 6),
             (X => 2, Y => 6)]);
   Crossing : constant Rotated_Rectangle_Intersection :=
     Intersect_Rotated_Rectangles
       ((Center        => (X => 0.0, Y => 0.0),
         Size          => (Width => 4.0, Height => 4.0),
         Angle_Degrees => 0.0),
        (Center        => (X => 2.0, Y => 0.0),
         Size          => (Width => 4.0, Height => 4.0),
         Angle_Degrees => 0.0));
begin
   --  The area is version independent; Width and Height may be swapped.
   pragma
     Assert (Near (Rectangle.Size.Width * Rectangle.Size.Height, 8.0, 1.0E-4));
   pragma Assert (Near (Rectangle.Center.X, 2.0, 1.0E-4));
   pragma Assert (Near (Rectangle.Center.Y, 1.0, 1.0E-4));
   --  Every box vertex is a rectangle corner, whatever the starting vertex.
   pragma
     Assert
       (for all Vertex of Vertices =>
          (for some Corner of Corners =>
             Near (Vertex.X, OpenCV.Float32_Value (Corner.X), 1.0E-4)
             and then Near
                        (Vertex.Y, OpenCV.Float32_Value (Corner.Y), 1.0E-4)));

   --  Full axis lengths, not radii.
   pragma Assert (Near (Ellipse.Center.X, 5.0, 0.1));
   pragma Assert (Near (Ellipse.Center.Y, 5.0, 0.1));
   pragma Assert (Ellipse.Size.Width in 19.0 .. 21.0);
   pragma Assert (Ellipse.Size.Height in 19.0 .. 21.0);

   --  A unit direction along Y = X + 1, through the centroid (3, 4).
   pragma Assert (Near (abs Line.Direction.X, 0.70710677, 1.0E-5));
   pragma Assert (Near (Line.Direction.X, Line.Direction.Y, 1.0E-5));
   pragma Assert (Near (Line.Point.X, 3.0, 1.0E-4));
   pragma Assert (Near (Line.Point.Y, 4.0, 1.0E-4));

   --  The circumscribed circle of the square, radius 2 * Sqrt (2) plus
   --  OpenCV's small EPS.
   pragma Assert (Near (Circle.Center.X, 2.0, 1.0E-3));
   pragma Assert (Near (Circle.Center.Y, 2.0, 1.0E-3));
   pragma Assert (Near (Circle.Radius, 2.828427, 1.0E-3));

   --  The two squares overlap in the square (2, 2) .. (4, 4).
   pragma Assert (Near (Overlap.Area, 4.0, 1.0E-4));
   pragma Assert (Overlap.Vertex_Count in 4 .. 8);
   pragma
     Assert
       (for all Vertex of Overlap.Vertices =>
          Vertex.X in 2.0 .. 4.0 and then Vertex.Y in 2.0 .. 4.0);

   pragma Assert (Crossing.Kind = Partial_Intersection);
   pragma Assert (Crossing.Vertex_Count >= 3);
end Fitting_And_Intersections;
```

## Interpreting results

- Rotated rectangles, ellipses and intersections are binary32 OpenCV
  results; compare them with tolerances and compare vertices as sets.
- For ordinary nondegenerate input, a minimum-area rectangle's region, and so
  its area, center and vertex set, is the same on every release; its
  `Width`, `Height` and angle are not.
- Fitting needs enough points: at least five for an ellipse, and two
  distinct points for a meaningful line direction. Each declaration lists
  the point counts and coordinate limits that raise `OpenCV.OpenCV_Error`.
- The [fundamentals guide](geometry-fundamentals-and-contours.md) describes
  the point types, and the
  [compatibility guide](compatibility-ownership-and-safety.md) summarizes the
  native limits that these operations guard.
