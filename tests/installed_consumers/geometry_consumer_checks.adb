with Ada.Text_IO;
with OpenCV;
with OpenCV.Core;
with OpenCV.Core.Float64_Access;
with OpenCV.Geometry;
with OpenCV.Geometry.Subdiv2D;

package body Geometry_Consumer_Checks is

   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point_Array;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Size_Coordinate;

   Failure_Count : Natural := 0;

   procedure Check (Condition : Boolean; Name : String) is
   begin
      if Condition then
         Ada.Text_IO.Put_Line ("ok " & Name);
      else
         Ada.Text_IO.Put_Line ("FAIL " & Name);
         Failure_Count := Failure_Count + 1;
      end if;
   end Check;

   function Failures return Natural is (Failure_Count);

   function Near (Left, Right, Tolerance : OpenCV.Float64_Value) return Boolean
   is (abs (Left - Right) <= Tolerance);

   --  Integer contour operations, including a variable-length result.
   procedure Integer_Contours is
      Square : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 10, Y => 0), (X => 10, Y => 10),
         (X => 0, Y => 10));
      With_Inside : constant OpenCV.Geometry.Contour :=
        Square & OpenCV.Geometry.Contour'(1 => (X => 5, Y => 5));
      Box  : constant OpenCV.Rect := OpenCV.Geometry.Bounding_Rect (Square);
      Hull : constant OpenCV.Geometry.Contour :=
        OpenCV.Geometry.Convex_Hull (With_Inside);
   begin
      Check
        (OpenCV.Geometry.Contour_Area (Square) = 100.0,
         "Contour_Area integer square");
      Check
        (OpenCV.Geometry.Arc_Length (Square, Closed => True) = 40.0,
         "Arc_Length closed integer square");
      Check
        (Box.X = 0 and then Box.Y = 0 and then Box.Width = 11
         and then Box.Height = 11,
         "Bounding_Rect integer square");
      Check (Hull'Length = 4, "Convex_Hull drops the interior point");
   end Integer_Contours;

   --  Float32 point-set operations and batch transforms.
   procedure Float32_Geometry is
      Triangle : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => 0.0, Y => 0.0), (X => 4.0, Y => 0.0), (X => 0.0, Y => 3.0));
      Left     : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => 0.0, Y => 0.0), (X => 2.0, Y => 0.0), (X => 2.0, Y => 2.0),
         (X => 0.0, Y => 2.0));
      Right    : constant OpenCV.Geometry.Float32_Point_Array :=
        ((X => 1.0, Y => 1.0), (X => 3.0, Y => 1.0), (X => 3.0, Y => 3.0),
         (X => 1.0, Y => 3.0));
      Overlap  : constant OpenCV.Geometry.Convex_Polygon_Intersection :=
        OpenCV.Geometry.Intersect_Convex_Polygons_Extended_Float32
          (Left, Right);
      --  Scale X by 2 and Y by 3, then translate by (10, 20).
      Affine   : constant OpenCV.Geometry.Affine_Transform_2D :=
        ((2.0, 0.0, 10.0), (0.0, 3.0, 20.0));
      Batch    : constant OpenCV.Geometry.Float32_Point_Array (5 .. 6) :=
        ((X => 0.0, Y => 0.0), (X => 2.0, Y => 1.0));
      Mapped   : constant OpenCV.Geometry.Float32_Point_Array :=
        OpenCV.Geometry.Transform_Points (Affine, Batch);
   begin
      Check
        (OpenCV.Geometry.Contour_Area (Triangle) = 6.0,
         "Contour_Area Float32 triangle");
      Check
        (Overlap.Vertex_Count = 4 and then abs (Overlap.Area - 1.0) <= 1.0E-6,
         "Intersect_Convex_Polygons_Extended_Float32 unit overlap");
      Check
        (Mapped'First = 5 and then Mapped'Last = 6
         and then Mapped (5).X = 10.0 and then Mapped (5).Y = 20.0
         and then Mapped (6).X = 14.0 and then Mapped (6).Y = 23.0,
         "Transform_Points Float32 batch keeps bounds");
   end Float32_Geometry;

   --  A Core Mat produced by Geometry and read through Core.
   procedure Rotation_Matrix is
      Rotation : constant OpenCV.Core.Mat :=
        OpenCV.Geometry.Get_Rotation_Matrix_2D
          (Center => (X => 0.0, Y => 0.0), Angle => 90.0);
   begin
      Check
        (OpenCV.Core.Rows (Rotation) = 2
         and then OpenCV.Core.Columns (Rotation) = 3,
         "Get_Rotation_Matrix_2D is 2x3");
      Check
        (Near (OpenCV.Core.Float64_Access.Get (Rotation, 0, 0), 0.0, 1.0E-12)
         and then Near
                    (OpenCV.Core.Float64_Access.Get (Rotation, 0, 1),
                     1.0,
                     1.0E-12)
         and then Near
                    (OpenCV.Core.Float64_Access.Get (Rotation, 1, 0),
                     -1.0,
                     1.0E-12),
         "Get_Rotation_Matrix_2D values through Core Float64_Access");
   end Rotation_Matrix;

   --  Construction, insertion, queries, native error translation and
   --  finalization of the one stateful Geometry type.
   procedure Subdivision_Lifecycle is
      use OpenCV.Geometry.Subdiv2D;
   begin
      declare
         Plane : Subdivision :=
           Create (Bounds => (X => 0, Y => 0, Width => 100, Height => 100));
      begin
         Insert
           (Plane,
            ((X => 10.0, Y => 10.0), (X => 90.0, Y => 10.0),
             (X => 50.0, Y => 90.0)));
         declare
            Center    : constant Vertex_Id :=
              Insert (Plane, (X => 50.0, Y => 40.0));
            Triangles : constant Triangle_Array := Triangle_List (Plane);
            Found     : constant Locate_Result :=
              Locate (Plane, (X => 50.0, Y => 40.0));
            Nearest   : constant Nearest_Result :=
              Find_Nearest (Plane, (X => 48.0, Y => 42.0));
            Diagram   : constant Voronoi_Diagram := Voronoi_Facets (Plane);
         begin
            Check (Is_Ready (Plane), "Subdiv2D ready after insertion");
            Check (Triangles'Length = 3, "Subdiv2D three Delaunay triangles");
            Check
              (Found.Kind = On_Vertex and then Found.Vertex = Center,
               "Subdiv2D Locate on the inserted vertex");
            Check (Nearest.Vertex = Center, "Subdiv2D Find_Nearest");
            Check (Diagram.Facet_Count = 4, "Subdiv2D four Voronoi facets");
         end;

         declare
            Outside : Vertex_Id := No_Vertex;
            Raised  : Boolean := False;
         begin
            begin
               Outside := Insert (Plane, (X => 500.0, Y => 500.0));
            exception
               when OpenCV.OpenCV_Error =>
                  Raised := True;
            end;
            Check
              (Raised and then Outside = No_Vertex and then Is_Ready (Plane),
               "Subdiv2D insertion outside the bounds raises OpenCV_Error"
               & " and keeps the subdivision ready");
         end;
      end;

      --  Repeated construction and finalization.
      for Iteration in 1 .. 100 loop
         declare
            Plane : Subdivision :=
              Create (Bounds => (X => 0, Y => 0, Width => 64, Height => 64));
            Vertex : constant Vertex_Id :=
              Insert (Plane, (X => 32.0, Y => 32.0));
         begin
            if Vertex = No_Vertex then
               Check
                 (False,
                  "Subdiv2D repeated lifecycle" & Integer'Image (Iteration));
            end if;
         end;
      end loop;
      Check (True, "Subdiv2D 100 create/insert/finalize cycles");
   end Subdivision_Lifecycle;

   function Run return Natural is
   begin
      Integer_Contours;
      Float32_Geometry;
      Rotation_Matrix;
      Subdivision_Lifecycle;
      return Failure_Count;
   end Run;

end Geometry_Consumer_Checks;
