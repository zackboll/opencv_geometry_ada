# Compatibility, ownership and native safety

This guide collects the rules shared by every operation of
`OpenCV.Geometry` and `OpenCV.Geometry.Subdiv2D`: which OpenCV releases they
support and where those releases differ, who owns results, how errors are
reported, and which native limits remain. The public Ada specifications are
authoritative: if this guide or the README disagrees with a declaration's
documentation in the API reference, the specification is right.

## Supported releases

The Ada declarations are the same on OpenCV 4.6, later 4.x releases and 5.x.
On OpenCV 4 the operations call the native imgproc library, and on OpenCV 5
the native geometry library. Where native results differ between releases,
the declaration says so; the most visible differences are these.

| Operation | Since | Newer behavior |
| --- | --- | --- |
| [Minimum_Area_Rectangle](api:Minimum_Area_Rectangle) | 4.13 | Angles in `[-90, 0)`, with a different width and height assignment |
| [Approximate_Curve](api:Approximate_Curve) | 5.x | Distances to the chord rather than to the line through it |
| [Fit_Ellipse](api:Fit_Ellipse) and its variants | 4.12 | Random perturbation of singular systems, from `cv::theRNG` |
| [Get_Perspective_Transform](api:Get_Perspective_Transform) | 4.12 | A unit-norm least-squares fallback whose `T (3, 3)` need not be 1.0 |
| [Float32 Minimum_Enclosing_Circle](api:Minimum_Enclosing_Circle/2) | 5.x | More than ten points shuffled before the search; results can differ in rounding, or more near degeneracy |
| [Triangle_List](api:Triangle_List) and [Voronoi_Facets](api:Voronoi_Facets) | 4.12 | A larger super-triangle, which changes results near the convex hull |

A 4.x version in the table means that release and every later one,
including 5.x.

## Native capabilities and binding coverage

[Is_Natively_Supported](api:Is_Natively_Supported) reports whether the linked
OpenCV provides a [Native_Feature](api:Native_Feature). The answer is fixed
when the native shim is built, and it never says whether an Ada operation
exists. Native `approxPolyN` and `minEnclosingConvexPolygon` remain unbound
even where OpenCV provides them, as do 3-D line fitting, the raster-image
modes of moments, bounding rectangles and shape matching, and Float32
enclosing triangles. Extracting contours from images belongs to the OpenCV
Imgproc binding.

Two features work on every supported release regardless of the answer:

- [Closest_Ellipse_Points](api:Closest_Ellipse_Points) is native on 4.12 and
  5.x and uses a private compatibility implementation on 4.6 to 4.11.
- Float32 subdivision bounds, through [Create_Float32](api:Create_Float32)
  and [Reset_Float32](api:Reset_Float32), use a private initialization
  backport before 4.13 and native `Rect2f` bounds from 4.13.

## Ownership

- Every operation of `OpenCV.Geometry` is a function that leaves its inputs
  unchanged and returns Ada-owned values, arrays and records; none refers to
  native storage.
- The one exception is [Get_Rotation_Matrix_2D](api:Get_Rotation_Matrix_2D),
  which returns an `OpenCV.Core.Mat` with Core's ordinary `Mat` ownership.
- A [Subdivision](api:Subdivision) is limited and owns its native object,
  which finalization releases. Its vertex and edge identifiers are
  meaningful only for that object, and for the lifetimes the
  [Subdiv2D guide](delaunay-and-voronoi.md#identifiers-and-their-lifetimes)
  describes.

## Errors

Input that the binding rejects, failures reported by OpenCV and non-finite
native results raise `OpenCV.OpenCV_Error`. Where native arithmetic or
memory safety requires it, an operation checks documented limits, such as
point counts and coordinate spans, before it calls OpenCV, and each
declaration states its own.

- Operations return a complete result or raise; none returns a partial
  result. The batch [Insert](api:Insert/2) of Subdiv2D is the one
  non-atomic operation: points before a rejected one stay inserted.
- A failed modification can leave a subdivision not ready; only a reset
  recovers it.
- [Facet_Points](api:Facet_Points) raises `Constraint_Error` for a facet
  index outside the diagram, as Ada indexing does.

## Native calls that may not return

Two native searches have no iteration bound. The binding cannot detect the
inputs that trigger them in advance, nor interrupt a native call:

- [Minimum_Enclosing_Triangle](api:Minimum_Enclosing_Triangle) can fail to
  return for some nearly degenerate hulls; it has no Float32 overload because
  binary32 point sets add more such inputs.
- [Find_Nearest](api:Find_Nearest) can fail to return for some numerically
  pathological triangulations.

Callers that need a deadline must not pass untrusted or poorly conditioned
geometry to either. A subdivision must also never be used by two tasks at
once, even for queries.

## Example

The example queries native capabilities, uses the two portable features,
and shows the error model.

```ada
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Subdiv2D;

--  Native capability queries, portable operations that work on every
--  supported OpenCV release, and the binding's error model.

procedure Compatibility_And_Safety is
   use OpenCV.Geometry;
   use type OpenCV.Float32_Value;
   use type OpenCV.Size_Coordinate;

   --  Native availability in the linked OpenCV, NOT Ada binding coverage:
   --  4.11 adds approxPolyN, 4.12 getClosestEllipsePoints, 4.13
   --  minEnclosingConvexPolygon and Rect2f subdivision bounds; 5.x has all.
   Polygon_N     : constant Boolean :=
     Is_Natively_Supported (Approximate_Convex_Polygon_Feature);
   Ellipse_Point : constant Boolean :=
     Is_Natively_Supported (Closest_Ellipse_Points_Feature);
   Enclosing     : constant Boolean :=
     Is_Natively_Supported (Minimum_Enclosing_Convex_Polygon_Feature);
   Float_Bounds  : constant Boolean :=
     Is_Natively_Supported (Float32_Subdivision_Bounds_Feature);

   --  Works on every release: native on 4.12+ and 5.x, a private
   --  compatibility implementation on 4.6 .. 4.11.
   Closest : constant Float32_Point_Array :=
     Closest_Ellipse_Points
       (Ellipse =>
          (Center        => (X => 0.0, Y => 0.0),
           Size          => (Width => 4.0, Height => 2.0),
           Angle_Degrees => 0.0),
        Points  => Float32_Point_Array'[(X => 10.0, Y => 0.0)]);

   Raised : Boolean;
begin
   --  The thresholds only grow with the release.
   pragma Assert (if Enclosing then Ellipse_Point and Polygon_N);
   pragma Assert (if Ellipse_Point then Polygon_N);
   pragma Assert (Float_Bounds = Enclosing);

   --  The point of the 4 x 2 ellipse (semi-axes 2 and 1) nearest (10, 0).
   pragma Assert (Closest'First = 0 and then Closest'Last = 0);
   pragma Assert (abs (Closest (0).X - 2.0) < 1.0E-3);
   pragma Assert (abs Closest (0).Y < 1.0E-3);

   --  Float32 subdivision bounds also work on every release.
   declare
      use OpenCV.Geometry.Subdiv2D;
      Plane : constant Subdivision :=
        Create_Float32 ((X => 0.5, Y => 0.5, Width => 9.0, Height => 9.0));
   begin
      pragma Assert (Bounds_Float32 (Plane).X = 0.5);
      --  Integer Bounds would have to round, so it raises instead.
      begin
         Raised := Bounds (Plane).Width = 0;
         Raised := False;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;
      pragma Assert (Raised);
   end;

   --  Rejected input raises OpenCV.OpenCV_Error; no partial result.
   begin
      Raised :=
        Fit_Ellipse (Contour'[(X => 0, Y => 0), (X => 1, Y => 1)]).Size.Width
        < 0.0;
      Raised := False;
   exception
      when OpenCV.OpenCV_Error =>
         Raised := True;
   end;
   pragma Assert (Raised);

   --  A declared but never created subdivision is not ready.
   declare
      use OpenCV.Geometry.Subdiv2D;
      Unused : Subdivision;
   begin
      pragma Assert (not Is_Ready (Unused));
      Raised := Insert (Unused, (X => 1.0, Y => 1.0)) = No_Vertex;
      Raised := False;
   exception
      when OpenCV.OpenCV_Error =>
         Raised := True;
   end;
   pragma Assert (Raised);
end Compatibility_And_Safety;
```

## Interpreting results

- Branch on [Is_Natively_Supported](api:Is_Natively_Supported) only to
  report the linked OpenCV, never to decide whether an Ada operation exists:
  every declaration is present on every supported release.
- Tests that must pass on several releases should check geometric
  properties, such as areas, vertex sets and mapped points, rather than
  native representations, orders or exact binary32 values.
- The other guides start with the
  [geometry fundamentals](geometry-fundamentals-and-contours.md).
