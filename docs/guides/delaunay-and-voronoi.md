# Delaunay and Voronoi with Subdiv2D

This guide covers `OpenCV.Geometry.Subdiv2D`, an incremental Delaunay
triangulation backed by one `cv::Subdiv2D`: creating and owning a
subdivision, inserting and locating points, walking its quad-edge structure,
and extracting the Voronoi diagram. The public Ada specifications are
authoritative: if this guide or the README disagrees with a declaration's
documentation in the API reference, the specification is right.

## Creating and owning a subdivision

A [Subdivision](api:Subdivision) exclusively owns its native object. It is
limited, so it cannot be copied, and finalization releases the native object
when the variable goes out of scope; no native handle is visible.

- [Create](api:Create) and [Reset](api:Reset) take integer bounds, and
  [Create_Float32](api:Create_Float32) and [Reset_Float32](api:Reset_Float32)
  binary32 bounds without rounding, on every supported release. Points are
  accepted in the half-open region from `X` to `X + Width` and from `Y` to
  `Y + Height`.
- A declared but never created object is not ready, and
  [Is_Ready](api:Is_Ready) reports it. Every operation except the bounds
  queries raises `OpenCV.OpenCV_Error` on an object that is not ready, and
  only a successful reset makes it ready again, for example after a failed
  insertion.
- [Bounds](api:Bounds) returns integer bounds and raises instead of rounding
  Float32 ones; [Bounds_Float32](api:Bounds_Float32) works for both.
- A subdivision must not be used by more than one task at a time, even for
  queries: OpenCV updates internal state in [Locate](api:Locate),
  [Find_Nearest](api:Find_Nearest) and [Voronoi_Facets](api:Voronoi_Facets).
  Distinct objects are independent.

## Inserting and locating points

The [single-point Insert](api:Insert) returns the point's
[Vertex_Id](api:Vertex_Id), or the existing vertex when OpenCV finds the
point coincident with one. The [batch Insert](api:Insert/2) is not atomic:
when OpenCV rejects a point, the earlier points stay inserted and the
exception message names the rejected index.

[Locate](api:Locate) returns a [Locate_Result](api:Locate_Result) whose
discriminant [Point_Location_Kind](api:Point_Location_Kind) says whether the
point lies inside a facet, on an edge, or on a vertex. Points outside the
bounds raise `OpenCV.OpenCV_Error`. [Find_Nearest](api:Find_Nearest)
returns the vertex whose Voronoi facet contains the query, normally the
nearest inserted vertex. Its native facet walk is unbounded, and some
numerically pathological triangulations can keep it from returning, so do
not rely on it for untrusted or poorly conditioned geometry when you need a
deadline.

## Identifiers and their lifetimes

Vertex and edge identifiers are OpenCV's and belong to the subdivision that
produced them.

- A [Vertex_Id](api:Vertex_Id) of an inserted point stays valid until the
  next reset. `No_Vertex` is 0, and 1 .. 3 are the vertices of OpenCV's
  bounding super-triangle, which lie outside the bounds. Identifiers are not
  dense, because Voronoi computation also creates vertices.
- An [Edge_Id](api:Edge_Id) stays valid only until the next insertion or
  reset: insertion flips edges and reuses their slots.

## Triangles, edges and navigation

[Triangle_List](api:Triangle_List) returns the triangles whose three vertices
lie inside the bounds, [Edge_List](api:Edge_List) the Delaunay edges as pairs
of positions, including edges to the super-triangle, and [Leading_Edge_List](api:Leading_Edge_List) one edge of each
facet. Results are Ada-owned arrays indexed `1 .. N` in native order. Near
the convex hull, triangles can differ between releases, because OpenCV 4.12
and later use a larger super-triangle.

Edges are directed. [Navigate](api:Navigate) follows one of the eight
[Edge_Navigation](api:Edge_Navigation) relations of OpenCV's quad-edge
structure, [Rotate](api:Rotate) selects one of the four
[Edge_Rotation](api:Edge_Rotation) members of an edge's quad-edge, and
[Symmetric_Edge](api:Symmetric_Edge), [Origin](api:Origin),
[Destination](api:Destination) and [Vertex_Point](api:Vertex_Point) answer
the common questions directly. A rotated edge is a dual Voronoi edge.

## Voronoi diagrams

[Voronoi_Facets](api:Voronoi_Facets) returns a
[Voronoi_Diagram](api:Voronoi_Diagram) with one facet per inserted point, in
increasing site order; the [second overload](api:Voronoi_Facets/2) returns
the facets of chosen sites. Each [Voronoi_Facet](api:Voronoi_Facet) names a
slice of the diagram's points, which [Facet_Points](api:Facet_Points)
copies.

- A facet whose region reaches beyond the super-triangle, as every facet on
  the convex hull does, is closed by far-away circumcenters that differ
  between releases.
- `Complete` is False when OpenCV could not create one of the facet's
  vertices; OpenCV then reports the origin in its place, so an incomplete
  polygon is not the true facet.

## Scale and conditioning

OpenCV's predicates use absolute binary32 tolerances, so behavior depends on
coordinate scale and conditioning. Probes on OpenCV 4.10 and 5.0 found no
nearest-vertex failures for random points about 0.03 units apart or more,
but some wrong answers at 0.01 units or less. These are observations, not a
safe minimum: scale your geometry so that distinct features are comfortably
separated.

## Example

The example triangulates four points tens of units apart, walks the
quad-edge structure, extracts the Voronoi diagram and resets the
subdivision.

```ada
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Subdiv2D;

--  Triangulates four well-separated points, walks the quad-edge structure,
--  extracts the Voronoi diagram and resets the subdivision. The points are
--  tens of units apart, far from the spacings where OpenCV's predicates lose
--  accuracy.

procedure Delaunay_And_Voronoi is
   use OpenCV.Geometry.Subdiv2D;
   use type OpenCV.Float32_Point;
   use type OpenCV.Size_Coordinate;

   --  The subdivision owns its native object and is released when Plane
   --  goes out of scope. It must not be shared between tasks.
   Plane : Subdivision :=
     Create (Bounds => (X => 0, Y => 0, Width => 100, Height => 100));
begin
   --  Three corners and one interior point: three Delaunay triangles.
   Insert
     (Plane,
      [(X => 10.0, Y => 10.0),
       (X => 90.0, Y => 10.0),
       (X => 50.0, Y => 90.0)]);
   declare
      Center    : constant Vertex_Id := Insert (Plane, (X => 50.0, Y => 40.0));
      Triangles : constant Triangle_Array := Triangle_List (Plane);
      Edges     : constant Edge_Id_Array := Leading_Edge_List (Plane);
      Edge      : constant Edge_Id := Edges (Edges'First);
      Walk      : Edge_Id := Edge;
      Found     : constant Locate_Result :=
        Locate (Plane, (X => 50.0, Y => 40.0));
      --  Well conditioned, so the native nearest-vertex walk returns.
      Nearest   : constant Nearest_Result :=
        Find_Nearest (Plane, (X => 48.0, Y => 42.0));
      Diagram   : constant Voronoi_Diagram := Voronoi_Facets (Plane);
   begin
      pragma Assert (Is_Ready (Plane));
      pragma Assert (Center > 3);  --  1 .. 3 are the super-triangle vertices
      pragma Assert (Triangles'Length = 3 and then Triangles'First = 1);

      --  Three steps around the facet on the left return to the edge.
      for Step in 1 .. 3 loop
         Walk := Navigate (Plane, Walk, Next_Around_Left);
      end loop;
      pragma Assert (Walk = Edge);
      --  Four dual rotations, or two reversals, return to the edge.
      Walk := Edge;
      for Step in 1 .. 4 loop
         Walk := Rotate (Plane, Walk, Rotated_Edge);
      end loop;
      pragma Assert (Walk = Edge);
      pragma
        Assert (Symmetric_Edge (Plane, Symmetric_Edge (Plane, Edge)) = Edge);
      pragma
        Assert
          (Origin (Plane, Symmetric_Edge (Plane, Edge))
             = Destination (Plane, Edge));

      pragma Assert (Found.Kind = On_Vertex and then Found.Vertex = Center);
      pragma Assert (Nearest.Vertex = Center);
      pragma Assert (Nearest.Point = Vertex_Point (Plane, Center));

      --  One facet per inserted point, in increasing site order.
      pragma Assert (Diagram.Facet_Count = 4);
      for Index in Diagram.Facets'Range loop
         pragma Assert (Diagram.Facets (Index).Complete);
         pragma Assert (Facet_Points (Diagram, Index)'Length >= 3);
         pragma
           Assert
             (Index = 1
                or else Diagram.Facets (Index - 1).Site
                        < Diagram.Facets (Index).Site);
      end loop;
      pragma Assert (for some Facet of Diagram.Facets => Facet.Site = Center);
   end;

   --  Reset discards every point; the old identifiers are no longer valid.
   Reset (Plane, (X => 0, Y => 0, Width => 10, Height => 10));
   pragma Assert (Is_Ready (Plane));
   pragma Assert (Voronoi_Facets (Plane).Facet_Count = 0);
   pragma Assert (Bounds (Plane).Width = 10);
end Delaunay_And_Voronoi;
```

## Interpreting results

- Compare triangles, edges and facets as sets: their order is OpenCV's.
- Query identifiers again after every insertion instead of keeping edge
  identifiers, and after every reset instead of keeping vertex identifiers.
- The far-away points that close hull facets, and triangles near the hull,
  depend on the OpenCV release.
- The [compatibility guide](compatibility-ownership-and-safety.md) covers
  Float32 bounds on older releases and the error model shared by both
  packages.
