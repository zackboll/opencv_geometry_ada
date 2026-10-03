with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;
with OpenCV.Geometry.Subdiv2D;

package body Subdiv2D_Foundation_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Subdiv renames OpenCV.Geometry.Subdiv2D;

   use type C_API.Status;
   use type C_API.Subdiv2D_Handle;
   use type Interfaces.C.C_float;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Point;
   use type OpenCV.Float32_Value;
   use type OpenCV.Geometry.Float32_Point_Array;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Rect;
   use type Subdiv.Point_Location_Kind;
   use type Subdiv.Vertex_Id;
   use type Subdiv.Edge_Id;

   subtype Points is OpenCV.Geometry.Float32_Point_Array;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => OpenCV.Float32_Value);

   --  IEEE special value; callers suppress validity checks.
   function NaN_32 return OpenCV.Float32_Value is
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float32 (16#7FC0_0000#);
   end NaN_32;

   Square : constant OpenCV.Rect :=
     (X => 0, Y => 0, Width => 100, Height => 100);

   --  Four points whose triangulation is identical on every supported
   --  release apart from edges to the super-triangle vertices.
   Fixture_Points : constant Points :=
     ((X => 10.0, Y => 10.0),
      (X => 90.0, Y => 10.0),
      (X => 50.0, Y => 80.0),
      (X => 50.0, Y => 40.0));

   procedure Assert_Raises_OpenCV_Error
     (Attempt : not null access procedure; Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;

      AUnit.Assertions.Assert (Raised, Message);
   end Assert_Raises_OpenCV_Error;

   --  The vertex at Point, which must have been inserted.
   function Vertex_At
     (Object : in out Subdiv.Subdivision; Point : OpenCV.Float32_Point)
      return Subdiv.Vertex_Id
   is
      Location : constant Subdiv.Locate_Result :=
        Subdiv.Locate (Object, Point);
   begin
      AUnit.Assertions.Assert
        (Location.Kind = Subdiv.On_Vertex,
         "an inserted point locates on a vertex");
      return Location.Vertex;
   end Vertex_At;

   function Is_Vertex
     (Object : in out Subdiv.Subdivision; Point : OpenCV.Float32_Point)
      return Boolean
   is (Subdiv.Locate (Object, Point).Kind = Subdiv.On_Vertex);

   procedure Create_And_Finalize (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      declare
         Object : constant Subdiv.Subdivision := Subdiv.Create (Square);
      begin
         AUnit.Assertions.Assert
           (Subdiv.Is_Ready (Object), "a created subdivision is ready");
         AUnit.Assertions.Assert
           (Subdiv.Bounds (Object) = Square, "Bounds reports the rectangle");
      end;

      --  Repeated creation and finalization, with and without points.
      for Iteration in 1 .. 200 loop
         declare
            Object : Subdiv.Subdivision := Subdiv.Create (Square);
         begin
            if Iteration mod 2 = 0 then
               Subdiv.Insert (Object, Fixture_Points);
            end if;
         end;
      end loop;
   end Create_And_Finalize;

   procedure Default_Object_Is_Not_Ready (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Object : Subdiv.Subdivision;

      procedure Insert_Point is
         Ignored : constant Subdiv.Vertex_Id :=
           Subdiv.Insert (Object, (X => 1.0, Y => 1.0));
      begin
         null;
      end Insert_Point;

      procedure Insert_Array is
      begin
         Subdiv.Insert (Object, Fixture_Points);
      end Insert_Array;

      procedure Locate_Point is
         Ignored : constant Subdiv.Locate_Result :=
           Subdiv.Locate (Object, (X => 1.0, Y => 1.0));
      begin
         null;
      end Locate_Point;

      procedure Nearest is
         Ignored : constant Subdiv.Nearest_Result :=
           Subdiv.Find_Nearest (Object, (X => 1.0, Y => 1.0));
      begin
         null;
      end Nearest;

      procedure Read_Bounds is
         Ignored : constant OpenCV.Rect := Subdiv.Bounds (Object);
      begin
         null;
      end Read_Bounds;
   begin
      AUnit.Assertions.Assert
        (not Subdiv.Is_Ready (Object),
         "a declared subdivision is not ready before Reset");
      Assert_Raises_OpenCV_Error
        (Insert_Point'Access, "Insert requires an initialized subdivision");
      Assert_Raises_OpenCV_Error
        (Insert_Array'Access,
         "array Insert requires an initialized subdivision");
      Assert_Raises_OpenCV_Error
        (Locate_Point'Access, "Locate requires an initialized subdivision");
      Assert_Raises_OpenCV_Error
        (Nearest'Access, "Find_Nearest requires an initialized subdivision");
      Assert_Raises_OpenCV_Error
        (Read_Bounds'Access, "Bounds requires an initialized subdivision");

      Subdiv.Reset (Object, Square);
      AUnit.Assertions.Assert
        (Subdiv.Is_Ready (Object) and then Subdiv.Bounds (Object) = Square,
         "Reset initializes a declared subdivision");
      AUnit.Assertions.Assert
        (Subdiv.Insert (Object, (X => 1.0, Y => 1.0)) > 3,
         "an initialized declared subdivision accepts points");
   end Default_Object_Is_Not_Ready;

   procedure Empty_Subdivision (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Object : Subdiv.Subdivision := Subdiv.Create (Square);

      procedure Nearest is
         Ignored : constant Subdiv.Nearest_Result :=
           Subdiv.Find_Nearest (Object, (X => 50.0, Y => 50.0));
      begin
         null;
      end Nearest;

      Location : constant Subdiv.Locate_Result :=
        Subdiv.Locate (Object, (X => 50.0, Y => 50.0));
   begin
      AUnit.Assertions.Assert
        (Location.Kind = Subdiv.Inside_Facet
         and then Location.Edge /= Subdiv.No_Edge,
         "a point in an empty subdivision lies in a super-triangle facet");
      Assert_Raises_OpenCV_Error
        (Nearest'Access, "Find_Nearest needs at least one inserted point");
      AUnit.Assertions.Assert
        (Subdiv.Is_Ready (Object),
         "a failed Find_Nearest leaves the subdivision ready");
   end Empty_Subdivision;

   procedure Insert_One (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
      Point  : constant OpenCV.Float32_Point := (X => 25.5, Y => 60.25);
      Vertex : constant Subdiv.Vertex_Id := Subdiv.Insert (Object, Point);
   begin
      AUnit.Assertions.Assert
        (Vertex > 3, "inserted vertices follow the reserved identifiers");
      AUnit.Assertions.Assert
        (Vertex_At (Object, Point) = Vertex,
         "Locate finds the inserted vertex");
      declare
         Nearest : constant Subdiv.Nearest_Result :=
           Subdiv.Find_Nearest (Object, (X => 70.0, Y => 20.0));
      begin
         AUnit.Assertions.Assert
           (Nearest.Vertex = Vertex and then Nearest.Point = Point,
            "the only vertex is the nearest one");
      end;
   end Insert_One;

   procedure Insert_Many (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
      Ids    : array (Fixture_Points'Range) of Subdiv.Vertex_Id;
   begin
      Subdiv.Insert (Object, Fixture_Points);
      for Index in Fixture_Points'Range loop
         Ids (Index) := Vertex_At (Object, Fixture_Points (Index));
         AUnit.Assertions.Assert
           (Ids (Index) > 3, "every inserted point has a vertex");
         for Earlier in Fixture_Points'First .. Index - 1 loop
            AUnit.Assertions.Assert
              (Ids (Earlier) /= Ids (Index),
               "distinct points have distinct vertices");
         end loop;
      end loop;
   end Insert_Many;

   procedure Duplicate_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
      Point  : constant OpenCV.Float32_Point := (X => 50.0, Y => 40.0);
      First  : constant Subdiv.Vertex_Id := Subdiv.Insert (Object, Point);
      Second : constant Subdiv.Vertex_Id := Subdiv.Insert (Object, Point);
   begin
      AUnit.Assertions.Assert
        (First = Second, "a duplicate insertion returns the existing vertex");
      Subdiv.Insert (Object, Fixture_Points & Fixture_Points);
      AUnit.Assertions.Assert
        (Vertex_At (Object, Point) = First,
         "array insertion of duplicates keeps the existing vertex");
   end Duplicate_Points;

   procedure Locate_Classifications (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
   begin
      Subdiv.Insert (Object, Fixture_Points);
      declare
         Interior : constant Subdiv.Locate_Result :=
           Subdiv.Locate (Object, (X => 50.0, Y => 20.0));
         On_Edge  : constant Subdiv.Locate_Result :=
           Subdiv.Locate (Object, (X => 50.0, Y => 60.0));
         Vertex   : constant Subdiv.Locate_Result :=
           Subdiv.Locate (Object, (X => 90.0, Y => 10.0));
      begin
         AUnit.Assertions.Assert
           (Interior.Kind = Subdiv.Inside_Facet
            and then Interior.Edge /= Subdiv.No_Edge,
            "a point inside a triangle lies inside a facet");
         AUnit.Assertions.Assert
           (On_Edge.Kind = Subdiv.On_Edge
            and then On_Edge.Edge /= Subdiv.No_Edge,
            "the midpoint of a Delaunay edge lies on an edge");
         AUnit.Assertions.Assert
           (Vertex.Kind = Subdiv.On_Vertex
            and then Vertex.Vertex
                     = Vertex_At (Object, (X => 90.0, Y => 10.0)),
            "an inserted point lies on its vertex");
      end;
   end Locate_Classifications;

   procedure Outside_And_Boundary_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Object : Subdiv.Subdivision := Subdiv.Create (Square);

      procedure Locate_Outside is
         Ignored : constant Subdiv.Locate_Result :=
           Subdiv.Locate (Object, (X => 150.0, Y => 50.0));
      begin
         null;
      end Locate_Outside;

      procedure Insert_Outside is
         Ignored : constant Subdiv.Vertex_Id :=
           Subdiv.Insert (Object, (X => 150.0, Y => 50.0));
      begin
         null;
      end Insert_Outside;

      procedure Insert_Upper_Edge is
         --  The bounds are half-open: X = Bounds.X + Bounds.Width is outside.
         Ignored : constant Subdiv.Vertex_Id :=
           Subdiv.Insert (Object, (X => 100.0, Y => 50.0));
      begin
         null;
      end Insert_Upper_Edge;

      procedure Nearest_Outside is
         Ignored : constant Subdiv.Nearest_Result :=
           Subdiv.Find_Nearest (Object, (X => 50.0, Y => -1.0));
      begin
         null;
      end Nearest_Outside;
   begin
      Assert_Raises_OpenCV_Error
        (Locate_Outside'Access,
         "Locate raises for a point outside the bounds");
      Assert_Raises_OpenCV_Error
        (Insert_Outside'Access,
         "Insert raises for a point outside the bounds");
      Assert_Raises_OpenCV_Error
        (Insert_Upper_Edge'Access,
         "the upper edges of the bounds are excluded");
      AUnit.Assertions.Assert
        (Subdiv.Is_Ready (Object),
         "rejected points leave the subdivision ready");

      --  The lower edges are included, and valid use continues after errors.
      AUnit.Assertions.Assert
        (Subdiv.Insert (Object, (X => 0.0, Y => 0.0)) > 3,
         "the lower corner of the bounds is accepted");
      Subdiv.Insert (Object, Fixture_Points);
      Assert_Raises_OpenCV_Error
        (Nearest_Outside'Access,
         "Find_Nearest raises for a point outside the bounds");
      AUnit.Assertions.Assert
        (Subdiv.Find_Nearest (Object, (X => 52.0, Y => 43.0)).Point
         = (X => 50.0, Y => 40.0),
         "valid queries still work after failed ones");
   end Outside_And_Boundary_Points;

   procedure Nearest_Vertex (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
   begin
      Subdiv.Insert (Object, Fixture_Points);
      declare
         Near  : constant Subdiv.Nearest_Result :=
           Subdiv.Find_Nearest (Object, (X => 52.0, Y => 43.0));
         Exact : constant Subdiv.Nearest_Result :=
           Subdiv.Find_Nearest (Object, (X => 90.0, Y => 10.0));
         Far   : constant Subdiv.Nearest_Result :=
           Subdiv.Find_Nearest (Object, (X => 12.0, Y => 95.0));
      begin
         AUnit.Assertions.Assert
           (Near.Point = (X => 50.0, Y => 40.0)
            and then Near.Vertex = Vertex_At (Object, (X => 50.0, Y => 40.0)),
            "the nearest vertex and its position");
         AUnit.Assertions.Assert
           (Exact.Point = (X => 90.0, Y => 10.0)
            and then Exact.Vertex = Vertex_At (Object, (X => 90.0, Y => 10.0)),
            "a query at a vertex reports that vertex and its position");
         AUnit.Assertions.Assert
           (Far.Point = (X => 50.0, Y => 80.0),
            "a distant query reports the closest inserted point");
      end;

      --  Voronoi data computed by Find_Nearest is invalidated by insertion.
      declare
         Added : constant Subdiv.Vertex_Id :=
           Subdiv.Insert (Object, (X => 15.0, Y => 90.0));
      begin
         AUnit.Assertions.Assert
           (Subdiv.Find_Nearest (Object, (X => 12.0, Y => 95.0)).Vertex
            = Added,
            "Find_Nearest sees points inserted after an earlier query");
      end;
   end Nearest_Vertex;

   procedure Independent_Subdivisions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Left  : Subdiv.Subdivision := Subdiv.Create (Square);
      Right : Subdiv.Subdivision :=
        Subdiv.Create ((X => 0, Y => 0, Width => 200, Height => 50));
      Point : constant OpenCV.Float32_Point := (X => 30.0, Y => 30.0);
   begin
      AUnit.Assertions.Assert
        (Subdiv.Insert (Left, Point) > 3,
         "the left subdivision accepts Point");
      AUnit.Assertions.Assert
        (not Is_Vertex (Right, Point),
         "inserting into one subdivision leaves another unchanged");
      AUnit.Assertions.Assert
        (Subdiv.Insert (Right, (X => 150.0, Y => 25.0)) > 3
         and then Is_Vertex (Right, (X => 150.0, Y => 25.0))
         and then Is_Vertex (Left, Point),
         "each subdivision keeps its own bounds and points");
   end Independent_Subdivisions;

   procedure Negative_Origin (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Object : Subdiv.Subdivision :=
        Subdiv.Create ((X => -50, Y => -20, Width => 10, Height => 10));

      procedure Beyond_Right_Edge is
         Ignored : constant Subdiv.Vertex_Id :=
           Subdiv.Insert (Object, (X => -40.0, Y => -15.0));
      begin
         null;
      end Beyond_Right_Edge;
   begin
      Subdiv.Insert
        (Object,
         Points'
           ((X => -45.0, Y => -15.0),
            (X => -49.0, Y => -19.5),
            (X => -41.0, Y => -11.0)));
      AUnit.Assertions.Assert
        (Is_Vertex (Object, (X => -45.0, Y => -15.0))
         and then Is_Vertex (Object, (X => -49.0, Y => -19.5))
         and then Is_Vertex (Object, (X => -41.0, Y => -11.0)),
         "points in a negative-origin rectangle are inserted");
      AUnit.Assertions.Assert
        (Subdiv.Find_Nearest (Object, (X => -44.0, Y => -14.0)).Point
         = (X => -45.0, Y => -15.0),
         "nearest-vertex queries work with negative coordinates");
      Assert_Raises_OpenCV_Error
        (Beyond_Right_Edge'Access,
         "X = Bounds.X + Bounds.Width is outside a negative-origin rectangle");
   end Negative_Origin;

   procedure Nonzero_Array_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object  : Subdiv.Subdivision := Subdiv.Create (Square);
      Shifted : constant Points (7 .. 10) := Fixture_Points;
   begin
      Subdiv.Insert (Object, Shifted);
      for Point of Shifted loop
         AUnit.Assertions.Assert
           (Is_Vertex (Object, Point),
            "every point of a shifted array is inserted");
      end loop;
      Subdiv.Insert (Object, Points'(5 .. 4 => (X => 0.0, Y => 0.0)));
      AUnit.Assertions.Assert
        (Subdiv.Is_Ready (Object), "an empty array inserts nothing");
   end Nonzero_Array_Bounds;

   procedure Reset_Discards_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
      Larger : constant OpenCV.Rect :=
        (X => 0, Y => 0, Width => 200, Height => 200);
   begin
      Subdiv.Insert (Object, Fixture_Points);
      Subdiv.Reset (Object, Larger);
      AUnit.Assertions.Assert
        (Subdiv.Is_Ready (Object) and then Subdiv.Bounds (Object) = Larger,
         "Reset installs the new bounds");
      for Point of Fixture_Points loop
         AUnit.Assertions.Assert
           (not Is_Vertex (Object, Point), "Reset discards earlier points");
      end loop;
      AUnit.Assertions.Assert
        (Subdiv.Insert (Object, (X => 150.0, Y => 150.0)) > 3,
         "points inside the new bounds are accepted");
      Subdiv.Reset (Object, Square);
      AUnit.Assertions.Assert
        (not Is_Vertex (Object, (X => 50.0, Y => 50.0))
         and then Subdiv.Bounds (Object) = Square,
         "repeated Reset works");
   end Reset_Discards_Points;

   procedure Rejects_Invalid_Bounds_And_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      Object : Subdiv.Subdivision := Subdiv.Create (Square);

      procedure Create_Zero_Width is
         Other : constant Subdiv.Subdivision :=
           Subdiv.Create ((X => 0, Y => 0, Width => 0, Height => 10));
      begin
         AUnit.Assertions.Assert
           (Subdiv.Is_Ready (Other), "unreachable: zero width accepted");
      end Create_Zero_Width;

      procedure Reset_Zero_Height is
      begin
         Subdiv.Reset (Object, (X => 5, Y => 5, Width => 10, Height => 0));
      end Reset_Zero_Height;

      procedure Insert_NaN is
         Ignored : constant Subdiv.Vertex_Id :=
           Subdiv.Insert (Object, (X => NaN_32, Y => 1.0));
      begin
         null;
      end Insert_NaN;

      procedure Insert_Array_With_NaN is
      begin
         Subdiv.Insert
           (Object, Points'((X => 20.0, Y => 20.0), (X => 30.0, Y => NaN_32)));
      end Insert_Array_With_NaN;

      procedure Locate_NaN is
         Ignored : constant Subdiv.Locate_Result :=
           Subdiv.Locate (Object, (X => NaN_32, Y => NaN_32));
      begin
         null;
      end Locate_NaN;
   begin
      Assert_Raises_OpenCV_Error
        (Create_Zero_Width'Access, "zero-width bounds are rejected");
      Assert_Raises_OpenCV_Error
        (Reset_Zero_Height'Access, "zero-height bounds are rejected");
      AUnit.Assertions.Assert
        (Subdiv.Is_Ready (Object) and then Subdiv.Bounds (Object) = Square,
         "a rejected Reset leaves the subdivision unchanged");
      Assert_Raises_OpenCV_Error
        (Insert_NaN'Access, "a NaN point is rejected");
      Assert_Raises_OpenCV_Error
        (Insert_Array_With_NaN'Access,
         "an array with a NaN point is rejected");
      AUnit.Assertions.Assert
        (not Is_Vertex (Object, (X => 20.0, Y => 20.0)),
         "non-finite arrays are rejected before any insertion");
      Assert_Raises_OpenCV_Error
        (Locate_NaN'Access, "Locate rejects a NaN point");
   end Rejects_Invalid_Bounds_And_Points;

   procedure Partial_Array_Insertion (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
      Batch  : constant Points (3 .. 6) :=
        ((X => 20.0, Y => 20.0),
         (X => 70.0, Y => 30.0),
         (X => 170.0, Y => 30.0),
         (X => 40.0, Y => 75.0));
      Raised : Boolean := False;
   begin
      begin
         Subdiv.Insert (Object, Batch);
      exception
         when Error : OpenCV.OpenCV_Error =>
            Raised := True;
            AUnit.Assertions.Assert
              (Ada.Strings.Fixed.Index
                 (Ada.Exceptions.Exception_Message (Error), "index 5")
               > 0,
               "the error names the index of the rejected point");
      end;
      AUnit.Assertions.Assert
        (Raised, "an array with a point outside the bounds raises");
      AUnit.Assertions.Assert
        (Is_Vertex (Object, Batch (3)) and then Is_Vertex (Object, Batch (4)),
         "points before the rejected one remain inserted");
      AUnit.Assertions.Assert
        (not Is_Vertex (Object, Batch (6)),
         "points after the rejected one are not inserted");
      AUnit.Assertions.Assert
        (Subdiv.Is_Ready (Object),
         "a rejected point leaves the subdivision ready");
   end Partial_Array_Insertion;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);

      function Bits_To_C_Float is new
        Ada.Unchecked_Conversion
          (Source => Interfaces.Unsigned_32,
           Target => Interfaces.C.C_float);

      Bounds     : aliased constant C_API.Rect_I32 :=
        (X => 0, Y => 0, Width => 100, Height => 100);
      Zero_Width : aliased constant C_API.Rect_I32 :=
        (X => 0, Y => 0, Width => 0, Height => 100);
      Handle     : aliased C_API.Subdiv2D_Handle := null;
      Saved      : C_API.Subdiv2D_Handle := null;
      Vertex     : aliased Interfaces.Integer_32 := 0;
      Count      : aliased Interfaces.Integer_32 := 0;
      Location   : aliased Interfaces.Integer_32 := 0;
      Edge       : aliased Interfaces.Integer_32 := 0;
      Position   : aliased C_API.Point_F32 := (X => 7.0, Y => 7.0);
      Batch      : aliased C_API.Point_F32_Array (0 .. 1) :=
        ((X => 10.0, Y => 10.0), (X => 90.0, Y => 10.0));
      Status     : C_API.Status;
   begin
      Status := C_API.Subdiv2D_Create (Bounds'Access, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then C_API.Last_Error_Message'Length > 0,
         "a null output handle pointer is rejected with a diagnostic");

      Status := C_API.Subdiv2D_Create (Bounds'Access, Handle'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Handle /= null
         and then C_API.Subdiv2D_Is_Usable (Handle) = 1,
         "a raw subdivision is created usable");
      Saved := Handle;
      Status := C_API.Subdiv2D_Create (null, Handle'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Handle = null,
         "failed creation publishes a null handle");
      Handle := Saved;

      C_API.Subdiv2D_Destroy (null);
      AUnit.Assertions.Assert
        (C_API.Subdiv2D_Is_Usable (null) = 0,
         "a null handle is never usable, and destroying it is harmless");

      Status := C_API.Subdiv2D_Init_Delaunay (null, Bounds'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "init_delaunay rejects a null handle");
      Status := C_API.Subdiv2D_Init_Delaunay (Handle, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then C_API.Subdiv2D_Is_Usable (Handle) = 1,
         "init_delaunay rejects null bounds and leaves the handle usable");

      Vertex := 99;
      Status := C_API.Subdiv2D_Insert (null, 1.0, 1.0, Vertex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Vertex = 0,
         "insert rejects a null handle and zeroes its output");
      Status := C_API.Subdiv2D_Insert (Handle, 1.0, 1.0, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "insert rejects a null vertex output");
      Vertex := 99;
      Status := C_API.Subdiv2D_Insert (Handle, 150.0, 1.0, Vertex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV
         and then Vertex = 0
         and then C_API.Subdiv2D_Is_Usable (Handle) = 1,
         "an OpenCV rejection before modification keeps the handle usable");
      --  The shim leaves finiteness policy to thick Ada. OpenCV cannot
      --  locate a NaN point and rejects it before modifying anything.
      Status :=
        C_API.Subdiv2D_Insert
          (Handle, Bits_To_C_Float (16#7FC0_0000#), 1.0, Vertex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV
         and then Vertex = 0
         and then C_API.Subdiv2D_Is_Usable (Handle) = 1,
         "a raw NaN insertion is rejected and keeps the handle usable");
      Status := C_API.Subdiv2D_Insert (Handle, 50.0, 40.0, Vertex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Vertex > 3,
         "a valid raw insertion returns a vertex");

      Count := 99;
      Status :=
        C_API.Subdiv2D_Insert_Points (null, Batch (0)'Access, 2, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Count = 0,
         "insert_points rejects a null handle and zeroes its output");
      Status :=
        C_API.Subdiv2D_Insert_Points
          (Handle, Batch (0)'Access, -1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "insert_points rejects a negative count");
      Status := C_API.Subdiv2D_Insert_Points (Handle, null, 2, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "insert_points rejects null points with a positive count");
      Status :=
        C_API.Subdiv2D_Insert_Points (Handle, Batch (0)'Access, 2, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "insert_points rejects a null count output");
      Status := C_API.Subdiv2D_Insert_Points (Handle, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 0,
         "insert_points accepts an empty batch");
      Status :=
        C_API.Subdiv2D_Insert_Points
          (Handle, Batch (0)'Access, 2, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 2,
         "insert_points reports every inserted point");
      Batch := ((X => 20.0, Y => 20.0), (X => 150.0, Y => 10.0));
      Status :=
        C_API.Subdiv2D_Insert_Points
          (Handle, Batch (0)'Access, 2, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV and then Count = 1,
         "insert_points reports the points inserted before a failure");

      Status :=
        C_API.Subdiv2D_Locate
          (Handle, 50.0, 20.0, null, Edge'Access, Vertex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "locate rejects a null location output");
      Location := 0;
      Edge := 99;
      Vertex := 99;
      Status :=
        C_API.Subdiv2D_Locate
          (null, 50.0, 20.0, Location'Access, Edge'Access, Vertex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Location = C_API.Subdiv2D_Location_Error
         and then Edge = 0
         and then Vertex = 0,
         "locate rejects a null handle with safe outputs");
      Status :=
        C_API.Subdiv2D_Locate
          (Handle, 90.0, 10.0, Location'Access, Edge'Access, Vertex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Location = C_API.Subdiv2D_Location_On_Vertex
         and then Vertex > 3,
         "a raw locate reports an inserted vertex");
      Status :=
        C_API.Subdiv2D_Locate
          (Handle, 150.0, 10.0, Location'Access, Edge'Access, Vertex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV
         and then Location = C_API.Subdiv2D_Location_Error,
         "a raw locate outside the bounds reports OpenCV's error");

      Status :=
        C_API.Subdiv2D_Find_Nearest
          (Handle, 50.0, 20.0, null, Position'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "find_nearest rejects a null vertex output");
      Status :=
        C_API.Subdiv2D_Find_Nearest (Handle, 50.0, 20.0, Vertex'Access, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "find_nearest rejects a null point output");
      Vertex := 99;
      Position := (X => 7.0, Y => 7.0);
      Status :=
        C_API.Subdiv2D_Find_Nearest
          (null, 50.0, 20.0, Vertex'Access, Position'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Vertex = 0
         and then Position.X = 0.0
         and then Position.Y = 0.0,
         "find_nearest rejects a null handle with zeroed outputs");
      Status :=
        C_API.Subdiv2D_Find_Nearest
          (Handle, 52.0, 43.0, Vertex'Access, Position'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Vertex > 3
         and then Position.X = 50.0
         and then Position.Y = 40.0,
         "a raw nearest-vertex query reports the vertex position");

      --  The positive-dimension policy belongs to thick Ada: the shim accepts
      --  zero-width native bounds, after which OpenCV rejects every point.
      Status := C_API.Subdiv2D_Init_Delaunay (Handle, Zero_Width'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "the shim accepts zero-width native bounds");
      Status := C_API.Subdiv2D_Insert (Handle, 0.0, 0.0, Vertex'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV
         and then C_API.Subdiv2D_Is_Usable (Handle) = 1,
         "OpenCV rejects every point inside zero-width bounds");

      C_API.Subdiv2D_Destroy (Handle);
   exception
      when others =>
         --  Release the raw handle when an assertion fails part-way.
         if Handle /= null then
            C_API.Subdiv2D_Destroy (Handle);
         elsif Saved /= null then
            C_API.Subdiv2D_Destroy (Saved);
         end if;
         raise;
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D create and finalize", Create_And_Finalize'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D declared object is not ready",
            Default_Object_Is_Not_Ready'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D empty subdivision", Empty_Subdivision'Access));
      Result.Add_Test
        (Caller.Create ("Subdiv2D insert one point", Insert_One'Access));
      Result.Add_Test
        (Caller.Create ("Subdiv2D insert many points", Insert_Many'Access));
      Result.Add_Test
        (Caller.Create ("Subdiv2D duplicate points", Duplicate_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D locate classifications", Locate_Classifications'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D outside and boundary points",
            Outside_And_Boundary_Points'Access));
      Result.Add_Test
        (Caller.Create ("Subdiv2D nearest vertex", Nearest_Vertex'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D independent subdivisions",
            Independent_Subdivisions'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D negative rectangle origin", Negative_Origin'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D nonzero array bounds", Nonzero_Array_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Reset discards points", Reset_Discards_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D rejects invalid bounds and points",
            Rejects_Invalid_Bounds_And_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D partial array insertion",
            Partial_Array_Insertion'Access));
      Result.Add_Test
        (Caller.Create ("Subdiv2D C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Subdiv2D_Foundation_Tests;
