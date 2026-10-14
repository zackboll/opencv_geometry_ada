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
