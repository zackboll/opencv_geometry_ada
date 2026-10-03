with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV.Geometry.Internal.C_API;
with OpenCV.Geometry.Subdiv2D;

package body Subdiv2D_Bounds_Tests is
   package C renames OpenCV.Geometry.Internal.C_API;
   package S renames OpenCV.Geometry.Subdiv2D;
   use type C.Status;
   use type C.Subdiv2D_Handle;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type OpenCV.Point_Coordinate;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float32_Point;
   use type OpenCV.Rect;
   use type S.Float32_Rectangle;
   use type S.Vertex_Id;
   use type S.Edge_Id;
   use type S.Point_Location_Kind;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Square              : constant OpenCV.Rect :=
     (X => 0, Y => 0, Width => 100, Height => 100);
   Fractional          : constant S.Float32_Rectangle :=
     (X => -0.25, Y => 0.5, Width => 10.5, Height => 12.25);
   Site                : constant OpenCV.Float32_Point :=
     (X => 2.25, Y => 3.5);
   Unsupported_Message : constant String :=
     "Subdiv2D Float32 bounds require OpenCV 4.13 or newer";

   function Supported return Boolean
   is (OpenCV.Geometry.Is_Natively_Supported
         (OpenCV.Geometry.Float32_Subdivision_Bounds_Feature));

   procedure Check (Condition : Boolean; Message : String) is
   begin
      AUnit.Assertions.Assert (Condition, Message);
   end Check;

   procedure Expect_Error
     (Attempt : not null access procedure; Message : String := "") is
   begin
      Attempt.all;
      Check (False, "expected OpenCV_Error: " & Message);
   exception
      when E : OpenCV.OpenCV_Error =>
         Check
           (Message'Length = 0
            or else Ada.Strings.Fixed.Index
                      (Ada.Exceptions.Exception_Message (E), Message)
                    > 0,
            "useful diagnostic: " & Ada.Exceptions.Exception_Message (E));
   end Expect_Error;

   procedure Assert_Stored
     (Object     : in out S.Subdivision;
      Descriptor : S.Float32_Rectangle;
      Vertex     : S.Vertex_Id) is
   begin
      Check (S.Is_Ready (Object), "rejection preserves readiness");
      Check (S.Bounds_Float32 (Object) = Descriptor, "bounds unchanged");
      Check
        (S.Locate (Object, Site).Vertex = Vertex,
         "rejection preserves triangulation");
   end Assert_Stored;

   procedure Reject_Float (Descriptor : S.Float32_Rectangle) is
      pragma Suppress (Validity_Check);
      Object : S.Subdivision := S.Create_Float32 (Fractional);
      Vertex : constant S.Vertex_Id := S.Insert (Object, Site);
      procedure Try_Reset is
      begin
         S.Reset_Float32 (Object, Descriptor);
      end Try_Reset;
      procedure Try_Create is
         Other : constant S.Subdivision := S.Create_Float32 (Descriptor);
      begin
         Check (not S.Is_Ready (Other), "invalid Create cannot succeed");
      end Try_Create;
   begin
      Expect_Error (Try_Create'Access);
      Expect_Error (Try_Reset'Access);
      Assert_Stored (Object, Fractional, Vertex);
   end Reject_Float;

   procedure Unsupported_Precedence (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : S.Subdivision := S.Create (Square);
      Vertex : constant S.Vertex_Id := S.Insert (Object, Site);
      procedure Try_Create is
         Other : constant S.Subdivision := S.Create_Float32 (Fractional);
      begin
         Check (not S.Is_Ready (Other), "unreachable unsupported Create");
      end Try_Create;
      procedure Try_Reset is
      begin
         S.Reset_Float32 (Object, S.Float32_Rectangle'(others => 0.0));
      end Try_Reset;
   begin
      if Supported then
         return;
      end if;
      Expect_Error (Try_Create'Access, Unsupported_Message);
      Expect_Error (Try_Reset'Access, Unsupported_Message);
      Check (S.Bounds (Object) = Square, "unsupported keeps integer mode");
      Assert_Stored
        (Object,
         (X => 0.0, Y => 0.0, Width => 100.0, Height => 100.0),
         Vertex);
   end Unsupported_Precedence;

   procedure Unsupported_Nonfinite (Test : in out Fixture) is
      pragma Unreferenced (Test);
      pragma Suppress (Validity_Check);
      function From_Bits is new
        Ada.Unchecked_Conversion
          (Interfaces.Unsigned_32,
           OpenCV.Float32_Value);
      Object : S.Subdivision := S.Create (Square);
      Bad    : constant S.Float32_Rectangle :=
        (X => From_Bits (16#7FC0_0000#), others => 0.0);
      procedure Try_Reset is
      begin
         S.Reset_Float32 (Object, Bad);
      end Try_Reset;
      procedure Try_Create is
         Other : constant S.Subdivision := S.Create_Float32 (Bad);
      begin
         Check (not S.Is_Ready (Other), "unreachable unsupported NaN");
      end Try_Create;
   begin
      if not Supported then
         Expect_Error (Try_Create'Access, Unsupported_Message);
         Expect_Error (Try_Reset'Access, Unsupported_Message);
         Check (S.Is_Ready (Object), "unsupported NaN does not mutate");
      end if;
   end Unsupported_Nonfinite;

   procedure Integer_Queries (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Rect :=
        (X => 2**24 + 1, Y => -7, Width => 4, Height => 10);
      Object   : constant S.Subdivision := S.Create (Original);
   begin
      Check (S.Bounds (Object) = Original, "original integers retained");
      Check
        (S.Bounds_Float32 (Object)
         = (X => 2.0**24, Y => -7.0, Width => 4.0, Height => 10.0),
         "each field is converted just as OpenCV converts it");

      --  Source compatibility with 0.1.0: these aggregates intentionally have
      --  no type qualification. Float32 APIs must not make them ambiguous.
      declare
         Legacy : S.Subdivision :=
           S.Create ((X => 0, Y => 0, Width => 100, Height => 100));
      begin
         Check (S.Is_Ready (Legacy), "unqualified integer Create is ready");
         Check (S.Bounds (Legacy) = Square, "aggregate resolves to Rect");
         S.Reset (Legacy, (X => -5, Y => -10, Width => 100, Height => 100));
         Check (S.Is_Ready (Legacy), "unqualified integer Reset is ready");
         Check
           (S.Bounds (Legacy)
            = (X => -5, Y => -10, Width => 100, Height => 100),
            "Reset aggregate retains integer bounds");
      end;
   end Integer_Queries;

   procedure Integer_Collapse (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : S.Subdivision := S.Create (Square);
      Vertex : constant S.Vertex_Id := S.Insert (Object, Site);
      Bad    : OpenCV.Rect := (X => 2**24, Y => 0, Width => 1, Height => 10);
      procedure Try_Reset is
      begin
         S.Reset (Object, Bad);
      end Try_Reset;
      procedure Try_Create is
         Other : constant S.Subdivision := S.Create (Bad);
      begin
         Check (not S.Is_Ready (Other), "collapsed Create cannot succeed");
      end Try_Create;
   begin
      Expect_Error (Try_Create'Access, "advance in binary32");
      Expect_Error (Try_Reset'Access, "advance in binary32");
      Bad := (X => 0, Y => 2**24, Width => 10, Height => 1);
      Expect_Error (Try_Reset'Access, "advance in binary32");
      Check (S.Bounds (Object) = Square, "failed integer Reset keeps bounds");
      Assert_Stored
        (Object,
         (X => 0.0, Y => 0.0, Width => 100.0, Height => 100.0),
         Vertex);
   end Integer_Collapse;

   procedure Integer_Advance (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Descriptor : constant OpenCV.Rect :=
        (X => 2**24, Y => 0, Width => 2, Height => 10);
      Object     : S.Subdivision := S.Create (Descriptor);
   begin
      Check (S.Is_Ready (Object), "one representable spacing accepted");
      Check
        (S.Insert (Object, (X => 2.0**24, Y => 5.0)) > 3,
         "native integer path accepts effective half-open interior");
      S.Reset (Object, Descriptor);
      Check (S.Bounds (Object) = Descriptor, "integer reset still available");
   end Integer_Advance;

   procedure Fractional_Create (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      if not Supported then
         return;
      end if;
      declare
         Object : constant S.Subdivision := S.Create_Float32 (Fractional);
         procedure Integer_Query is
            Ignored : constant OpenCV.Rect := S.Bounds (Object);
            pragma Unreferenced (Ignored);
         begin
            null;
         end Integer_Query;
      begin
         Check (S.Is_Ready (Object), "fractional Create is ready");
         Check (S.Bounds_Float32 (Object) = Fractional, "exact descriptor");
         Expect_Error
           (Integer_Query'Access, "initialized with Float32 bounds");
      end;
   end Fractional_Create;

   procedure Mode_Switching (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object  : S.Subdivision := S.Create (Square);
      Shifted : constant S.Float32_Rectangle :=
        (X => -1.5, Y => -2.25, Width => 20.5, Height => 25.75);
   begin
      if not Supported then
         return;
      end if;
      Check (S.Insert (Object, Site) > 3, "integer site inserted");
      S.Reset_Float32 (Object, Fractional);
      Check (S.Bounds_Float32 (Object) = Fractional, "integer to Float32");
      Check
        (S.Locate (Object, Site).Kind /= S.On_Vertex, "Reset removes site");
      Check (S.Insert (Object, Site) > 3, "fractional site inserted");
      S.Reset_Float32 (Object, Shifted);
      Check (S.Bounds_Float32 (Object) = Shifted, "fractional Reset");
      Check
        (S.Locate (Object, Site).Kind /= S.On_Vertex, "Reset discards site");
      S.Reset (Object, Square);
      Check (S.Bounds (Object) = Square, "Float32 to integer");
      Check
        (S.Locate (Object, Site).Kind /= S.On_Vertex, "integer Reset clears");
      S.Reset_Float32 (Object, Fractional);
      Check (S.Is_Ready (Object), "modes alternate on the same owner");
   end Mode_Switching;

   procedure Fractional_Operations (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      if not Supported then
         return;
      end if;
      declare
         Object : S.Subdivision := S.Create_Float32 (Fractional);
         Vertex : constant S.Vertex_Id := S.Insert (Object, Site);
      begin
         S.Insert
           (Object,
            OpenCV.Geometry.Float32_Point_Array'
              ((X => 8.25, Y => 2.5),
               (X => 5.25, Y => 10.5),
               (X => 5.25, Y => 6.5)));
         Check (S.Locate (Object, Site).Vertex = Vertex, "fractional Locate");
         Check
           (S.Find_Nearest (Object, (X => 2.5, Y => 3.75)).Vertex = Vertex,
            "fractional nearest");
         Check (S.Edge_List (Object)'Length > 0, "fractional edges");
         Check (S.Triangle_List (Object)'Length = 3, "fractional triangles");
         declare
            Edges  : constant S.Edge_Id_Array := S.Leading_Edge_List (Object);
            E      : constant S.Edge_Id := Edges (Edges'First);
            Facets : constant S.Voronoi_Diagram := S.Voronoi_Facets (Object);
         begin
            Check (S.Origin (Object, E) > 0, "navigation still works");
            Check
              (S.Navigate
                 (Object,
                  S.Navigate (Object, E, S.Next_Around_Left),
                  S.Previous_Around_Left)
               = E,
               "navigation inverse");
            Check (Facets.Facet_Count = 4, "fractional Voronoi sites");
         end;
      end;
   end Fractional_Operations;

   procedure Half_Open (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      if not Supported then
         return;
      end if;
      declare
         Object : S.Subdivision := S.Create_Float32 (Fractional);
         Point  : OpenCV.Float32_Point;
         procedure Try_Insert is
            Ignored : constant S.Vertex_Id := S.Insert (Object, Point);
            pragma Unreferenced (Ignored);
         begin
            null;
         end Try_Insert;
         procedure Try_Locate is
            Ignored : constant S.Locate_Result := S.Locate (Object, Point);
            pragma Unreferenced (Ignored);
         begin
            null;
         end Try_Locate;
      begin
         Check
           (S.Insert (Object, (X => Fractional.X, Y => Fractional.Y)) > 3,
            "left/top corner included");
         Check
           (S.Insert (Object, (X => -0.25, Y => 5.5)) > 3, "left included");
         Check (S.Insert (Object, (X => 4.25, Y => 0.5)) > 3, "top included");
         for P of
           OpenCV.Geometry.Float32_Point_Array'
             ((X => 10.25, Y => 5.5),
              (X => 4.25, Y => 12.75),
              (X => -1.25, Y => 5.5),
              (X => 4.25, Y => -0.5))
         loop
            Point := P;
            Expect_Error (Try_Insert'Access);
            Expect_Error (Try_Locate'Access);
            Check (S.Is_Ready (Object), "outside queries preserve readiness");
         end loop;
      end;
   end Half_Open;

   procedure Super_Triangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      if not Supported then
         return;
      end if;
      declare
         Object : constant S.Subdivision := S.Create_Float32 (Fractional);
      begin
         Check (S.Vertex_Point (Object, 1) = (73.25, 0.5), "A: X+Big,Y");
         Check (S.Vertex_Point (Object, 2) = (-0.25, 74.0), "B: X,Y+Big");
         Check
           (S.Vertex_Point (Object, 3) = (-73.75, -73.0), "C: X-Big,Y-Big");
      end;
   end Super_Triangle;

   procedure Nonfinite (Bits : Interfaces.Unsigned_32) is
      pragma Suppress (Validity_Check);
      function From_Bits is new
        Ada.Unchecked_Conversion
          (Interfaces.Unsigned_32,
           OpenCV.Float32_Value);
      Bad : S.Float32_Rectangle;
   begin
      if not Supported then
         return;
      end if;
      for Field in 1 .. 4 loop
         Bad := Fractional;
         case Field is
            when 1 =>
               Bad.X := From_Bits (Bits);

            when 2 =>
               Bad.Y := From_Bits (Bits);

            when 3 =>
               Bad.Width := From_Bits (Bits);

            when 4 =>
               Bad.Height := From_Bits (Bits);
         end case;
         Reject_Float (Bad);
      end loop;
   end Nonfinite;

   procedure NaN_Fields (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Nonfinite (16#7FC0_0000#);
   end NaN_Fields;

   procedure Positive_Infinity (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Nonfinite (16#7F80_0000#);
   end Positive_Infinity;

   procedure Negative_Infinity (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Nonfinite (16#FF80_0000#);
   end Negative_Infinity;

   procedure Dimensions (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      if Supported then
         Reject_Float ((X => 0.0, Y => 0.0, Width => 0.0, Height => 10.0));
         Reject_Float ((X => 0.0, Y => 0.0, Width => -1.0, Height => 10.0));
         Reject_Float ((X => 0.0, Y => 0.0, Width => 10.0, Height => 0.0));
         Reject_Float ((X => 0.0, Y => 0.0, Width => 10.0, Height => -1.0));
      end if;
   end Dimensions;

   procedure Float_Collapse (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      if Supported then
         Reject_Float ((X => 2.0**24, Y => 0.0, Width => 1.0, Height => 10.0));
         Reject_Float ((X => 0.0, Y => 2.0**24, Width => 10.0, Height => 1.0));
      end if;
   end Float_Collapse;

   procedure Float_Advance (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      if Supported then
         declare
            Descriptor : constant S.Float32_Rectangle :=
              (X => 2.0**24, Y => 0.0, Width => 2.0, Height => 10.0);
            Object     : S.Subdivision := S.Create_Float32 (Descriptor);
         begin
            Check
              (S.Insert (Object, (X => 2.0**24, Y => 5.0)) > 3,
               "representably positive Float32 width accepted");
         end;
      end if;
   end Float_Advance;

   procedure Scale_Overflow (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      if Supported then
         Reject_Float ((X => 0.0, Y => 0.0, Width => 1.0E38, Height => 10.0));
         Reject_Float ((X => 0.0, Y => 0.0, Width => 10.0, Height => 1.0E38));
      end if;
   end Scale_Overflow;

   procedure Coordinate_Overflow (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      if Supported then
         --  Big is finite (3E38), and upper limits advance, but each of the
         --  four X/Y +/- Big expressions overflows in the respective case.
         Reject_Float
           ((X => 1.0E38, Y => 0.0, Width => 5.0E37, Height => 5.0E37));
         Reject_Float
           ((X => 0.0, Y => 1.0E38, Width => 5.0E37, Height => 5.0E37));
         Reject_Float
           ((X => -1.0E38, Y => 0.0, Width => 5.0E37, Height => 5.0E37));
         Reject_Float
           ((X => 0.0, Y => -1.0E38, Width => 5.0E37, Height => 5.0E37));
         Reject_Float
           ((X      => OpenCV.Float32_Value'Last,
             Y      => 0.0,
             Width  => 5.0E37,
             Height => 10.0));
         Reject_Float
           ((X      => 0.0,
             Y      => OpenCV.Float32_Value'Last,
             Width  => 10.0,
             Height => 5.0E37));
      end if;
   end Coordinate_Overflow;

   procedure Uninitialized_Query (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : S.Subdivision;
      procedure Query is
         Ignored : constant S.Float32_Rectangle := S.Bounds_Float32 (Object);
         pragma Unreferenced (Ignored);
      begin
         null;
      end Query;
   begin
      Expect_Error (Query'Access, "successful Create or Reset");
   end Uninitialized_Query;

   procedure Cross_Mode_Rejection (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : S.Subdivision := S.Create (Square);
      Vertex : S.Vertex_Id := S.Insert (Object, Site);
      procedure Bad_Float is
      begin
         S.Reset_Float32 (Object, S.Float32_Rectangle'(others => 0.0));
      end Bad_Float;
      procedure Bad_Integer is
      begin
         S.Reset
           (Object,
            OpenCV.Rect'(X => 2**24, Y => 0, Width => 1, Height => 10));
      end Bad_Integer;
      procedure Integer_Query is
         Ignored : constant OpenCV.Rect := S.Bounds (Object);
         pragma Unreferenced (Ignored);
      begin
         null;
      end Integer_Query;
   begin
      if not Supported then
         return;
      end if;
      Expect_Error (Bad_Float'Access);
      Check
        (S.Bounds (Object) = Square, "failed Float32 Reset keeps int mode");
      Assert_Stored
        (Object,
         (X => 0.0, Y => 0.0, Width => 100.0, Height => 100.0),
         Vertex);
      S.Reset_Float32 (Object, Fractional);
      Vertex := S.Insert (Object, Site);
      Expect_Error (Bad_Integer'Access);
      Assert_Stored (Object, Fractional, Vertex);
      Expect_Error (Integer_Query'Access, "initialized with Float32 bounds");
   end Cross_Mode_Rejection;

   procedure Finite_Extremes (Test : in out Fixture) is
      pragma Unreferenced (Test);
      function From_Bits is new
        Ada.Unchecked_Conversion
          (Interfaces.Unsigned_32,
           OpenCV.Float32_Value);
      Tiny   : constant OpenCV.Float32_Value := From_Bits (1);
      Huge   : constant OpenCV.Float32_Value :=
        OpenCV.Float32_Value'Last / 8.0;
      Object : S.Subdivision;
   begin
      if not Supported then
         return;
      end if;
      --  Test initialization/storage only, not pathological native predicates.
      S.Reset_Float32
        (Object,
         S.Float32_Rectangle'
           (X => 0.0, Y => 0.0, Width => Tiny, Height => Tiny));
      Check (S.Is_Ready (Object), "subnormal positive bounds not prohibited");
      Check (S.Bounds_Float32 (Object).Width = Tiny, "subnormal retained");
      Check (S.Vertex_Point (Object, 1).X = 6.0 * Tiny, "tiny Big retained");
      S.Reset_Float32
        (Object,
         S.Float32_Rectangle'
           (X => 0.0, Y => 0.0, Width => Huge, Height => Huge));
      Check (S.Is_Ready (Object), "large finite initialization accepted");
      Check (S.Bounds_Float32 (Object).Width = Huge, "large exact descriptor");
   end Finite_Extremes;

   procedure Raw_Ordering (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Has_Float_Bounds : constant Boolean := Supported;
      Descriptor       : aliased constant C.Rect_F32 :=
        (-0.25, 0.5, 10.5, 12.25);
      Integers         : aliased constant C.Rect_I32 := (0, 0, 100, 100);
      Handle           : aliased C.Subdiv2D_Handle := null;
      Saved            : C.Subdiv2D_Handle := null;
      Status           : C.Status;
   begin
      Status := C.Subdiv2D_Create_F32 (null, null);
      Check (Status = C.Error_Invalid_Argument, "out_handle always required");
      Check (C.Last_Error_Message'Length > 0, "null output diagnostic");
      Status := C.Subdiv2D_Create (Integers'Access, Handle'Access);
      Check (Status = C.Success, "safe non-null sentinel is a live handle");
      Saved := Handle;
      Status := C.Subdiv2D_Create_F32 (null, Handle'Access);
      Check (Handle = null, "failure/unsupported publishes null");
      if not Has_Float_Bounds then
         Check
           (Status = C.Error_Unsupported, "old Create ignores null bounds");
         Check (C.Last_Error_Message = Unsupported_Message, "version message");
         Status := C.Subdiv2D_Init_Delaunay_F32 (null, null);
         Check (Status = C.Error_Unsupported, "old Reset ignores null args");
         Status := C.Subdiv2D_Init_Delaunay_F32 (Saved, null);
         Check (Status = C.Error_Unsupported, "old Reset ignores bounds");
         Check (C.Subdiv2D_Is_Usable (Saved) = 1, "old Reset keeps usable");
      else
         Check (Status = C.Error_Invalid_Argument, "supported needs bounds");
         Status := C.Subdiv2D_Init_Delaunay_F32 (null, Descriptor'Access);
         Check (Status = C.Error_Invalid_Argument, "Reset needs handle");
         Status := C.Subdiv2D_Init_Delaunay_F32 (Saved, null);
         Check (Status = C.Error_Invalid_Argument, "Reset needs bounds");
         Check (C.Subdiv2D_Is_Usable (Saved) = 1, "bad pointers keep usable");
         Status := C.Subdiv2D_Create_F32 (Descriptor'Access, Handle'Access);
         Check (Status = C.Success and then Handle /= null, "raw f32 Create");
         Status := C.Subdiv2D_Init_Delaunay_F32 (Saved, Descriptor'Access);
         Check (Status = C.Success, "raw f32 Reset");
         Check (C.Subdiv2D_Is_Usable (Saved) = 1, "successful Reset ready");
      end if;
      C.Subdiv2D_Destroy (Handle);
      Handle := null;
      C.Subdiv2D_Destroy (Saved);
      Saved := null;
   exception
      when others =>
         C.Subdiv2D_Destroy (Handle);
         C.Subdiv2D_Destroy (Saved);
         raise;
   end Raw_Ordering;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D rejected cross-mode Reset",
            Cross_Mode_Rejection'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D finite extreme initialization", Finite_Extremes'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Float32 unsupported precedence",
            Unsupported_Precedence'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Float32 unsupported NaN", Unsupported_Nonfinite'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D integer bounds queries", Integer_Queries'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D integer binary32 collapse", Integer_Collapse'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D integer binary32 advance", Integer_Advance'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D fractional Create and queries",
            Fractional_Create'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Reset representation switching", Mode_Switching'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D fractional operations", Fractional_Operations'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D fractional half-open bounds", Half_Open'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Rect2f super-triangle", Super_Triangle'Access));
      Result.Add_Test
        (Caller.Create ("Subdiv2D bounds NaN fields", NaN_Fields'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D bounds positive infinity", Positive_Infinity'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D bounds negative infinity", Negative_Infinity'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D bounds nonpositive dimensions", Dimensions'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Float32 binary32 collapse", Float_Collapse'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Float32 binary32 advance", Float_Advance'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D super-triangle scale overflow", Scale_Overflow'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D initialization coordinate overflow",
            Coordinate_Overflow'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D uninitialized Float32 bounds query",
            Uninitialized_Query'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Float32 raw argument ordering", Raw_Ordering'Access));
      return Result'Access;
   end Suite;
end Subdiv2D_Bounds_Tests;
