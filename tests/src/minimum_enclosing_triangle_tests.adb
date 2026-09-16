with Ada.Strings.Fixed;
with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

package body Minimum_Enclosing_Triangle_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type Interfaces.C.C_float;
   use type Interfaces.C.double;
   use type OpenCV.Float32_Value;
   use type OpenCV.Float64_Value;
   use type OpenCV.Point;
   use type OpenCV.Point_Coordinate;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Area_Tolerance   : constant OpenCV.Float64_Value := 1.0E-3;
   Vertex_Tolerance : constant OpenCV.Float32_Value := 1.0E-3;
   Inside_Tolerance : constant OpenCV.Float64_Value := 1.0E-2;

   Triangle      : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 0, Y => 3));
   Square        : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 4, Y => 0), (X => 4, Y => 4), (X => 0, Y => 4));
   Irregular     : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0), (X => 5, Y => 0), (X => 6, Y => 3), (X => 2, Y => 4));
   Concave       : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 4),
      (X => 2, Y => 1),
      (X => 0, Y => 4));
   With_Interior : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 0),
      (X => 4, Y => 0),
      (X => 4, Y => 4),
      (X => 0, Y => 4),
      (X => 2, Y => 2));
   Translated    : constant OpenCV.Geometry.Contour :=
     ((X => -10, Y => -6), (X => -6, Y => -6), (X => -10, Y => -3));
   Reordered     : constant OpenCV.Geometry.Contour :=
     ((X => 0, Y => 3), (X => 0, Y => 0), (X => 4, Y => 0));

   function Close64 (Left, Right : OpenCV.Float64_Value) return Boolean is
   begin
      return abs (Left - Right) <= Area_Tolerance;
   end Close64;

   function Close32 (Left, Right : OpenCV.Float32_Value) return Boolean is
   begin
      return abs (Left - Right) <= Vertex_Tolerance;
   end Close32;

   function Same_Vertex (Left, Right : OpenCV.Float32_Point) return Boolean is
   begin
      return Close32 (Left.X, Right.X) and then Close32 (Left.Y, Right.Y);
   end Same_Vertex;

   function Independent_Area
     (Vertices : OpenCV.Geometry.Triangle_Vertices) return OpenCV.Float64_Value
   is
      A : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Vertices (1).X);
      B : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Vertices (1).Y);
      C : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Vertices (2).X);
      D : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Vertices (2).Y);
      E : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Vertices (3).X);
      F : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Vertices (3).Y);
   begin
      return abs ((A * (D - F) + C * (F - B) + E * (B - D)) / 2.0);
   end Independent_Area;

   function Cross (A, B, P : OpenCV.Float32_Point) return OpenCV.Float64_Value
   is
   begin
      return
        OpenCV.Float64_Value (B.X - A.X)
        * OpenCV.Float64_Value (P.Y - A.Y)
        - OpenCV.Float64_Value (B.Y - A.Y) * OpenCV.Float64_Value (P.X - A.X);
   end Cross;

   function Point_In_Triangle
     (Query    : OpenCV.Float32_Point;
      Vertices : OpenCV.Geometry.Triangle_Vertices) return Boolean
   is
      C1      : constant OpenCV.Float64_Value :=
        Cross (Vertices (1), Vertices (2), Query);
      C2      : constant OpenCV.Float64_Value :=
        Cross (Vertices (2), Vertices (3), Query);
      C3      : constant OpenCV.Float64_Value :=
        Cross (Vertices (3), Vertices (1), Query);
      Has_Neg : constant Boolean :=
        C1 < -Inside_Tolerance
        or else C2 < -Inside_Tolerance
        or else C3 < -Inside_Tolerance;
      Has_Pos : constant Boolean :=
        C1 > Inside_Tolerance
        or else C2 > Inside_Tolerance
        or else C3 > Inside_Tolerance;
   begin
      return not (Has_Neg and then Has_Pos);
   end Point_In_Triangle;

   function All_Points_Inside
     (Points   : OpenCV.Geometry.Contour;
      Vertices : OpenCV.Geometry.Triangle_Vertices) return Boolean is
   begin
      for Point of Points loop
         if not Point_In_Triangle
                  ((X => OpenCV.Float32_Value (Point.X),
                    Y => OpenCV.Float32_Value (Point.Y)),
                   Vertices)
         then
            return False;
         end if;
      end loop;
      return True;
   end All_Points_Inside;

   function Vertex_Matches_Any_Source
     (Vertex : OpenCV.Float32_Point; Points : OpenCV.Geometry.Contour)
      return Boolean is
   begin
      for Point of Points loop
         if Close32 (Vertex.X, OpenCV.Float32_Value (Point.X))
           and then Close32 (Vertex.Y, OpenCV.Float32_Value (Point.Y))
         then
            return True;
         end if;
      end loop;
      return False;
   end Vertex_Matches_Any_Source;

   function Same_Vertex_Set
     (Actual   : OpenCV.Geometry.Triangle_Vertices;
      Expected : OpenCV.Geometry.Triangle_Vertices) return Boolean
   is
      Used  : array (OpenCV.Geometry.Triangle_Vertex_Index) of Boolean :=
        (others => False);
      Found : Boolean;
   begin
      for Index in Actual'Range loop
         Found := False;
         for Candidate in Expected'Range loop
            if not Used (Candidate)
              and then Same_Vertex (Actual (Index), Expected (Candidate))
            then
               Used (Candidate) := True;
               Found := True;
               exit;
            end if;
         end loop;
         if not Found then
            return False;
         end if;
      end loop;
      return True;
   end Same_Vertex_Set;

   function Same_Contour (Left, Right : OpenCV.Geometry.Contour) return Boolean
   is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      if Left'Length = 0 then
         return True;
      end if;
      for Offset in 0 .. Left'Length - 1 loop
         if Left (Left'First + Offset) /= Right (Right'First + Offset) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Contour;

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

   procedure Ordinary_Triangle (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Actual   : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Triangle);
      Expected : constant OpenCV.Geometry.Triangle_Vertices :=
        ((X => 0.0, Y => 0.0), (X => 4.0, Y => 0.0), (X => 0.0, Y => 3.0));
   begin
      AUnit.Assertions.Assert (Close64 (Actual.Area, 6.0), "triangle area");
      AUnit.Assertions.Assert
        (Close64 (Independent_Area (Actual.Vertices), Actual.Area),
         "triangle independent area");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Actual.Vertices, Expected),
         "triangle vertices reproduce input");
      AUnit.Assertions.Assert
        (All_Points_Inside (Triangle, Actual.Vertices),
         "triangle points inside");
   end Ordinary_Triangle;

   procedure Axis_Aligned_Square (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Square);
   begin
      AUnit.Assertions.Assert (Close64 (Actual.Area, 32.0), "square area");
      AUnit.Assertions.Assert
        (Close64 (Independent_Area (Actual.Vertices), Actual.Area),
         "square independent area");
      AUnit.Assertions.Assert
        (All_Points_Inside (Square, Actual.Vertices), "square points inside");
   end Axis_Aligned_Square;

   procedure Irregular_Convex (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Irregular);
   begin
      AUnit.Assertions.Assert (Actual.Area > 0.0, "irregular positive area");
      AUnit.Assertions.Assert
        (Close64 (Independent_Area (Actual.Vertices), Actual.Area),
         "irregular independent area");
      AUnit.Assertions.Assert
        (All_Points_Inside (Irregular, Actual.Vertices),
         "irregular points inside");
   end Irregular_Convex;

   procedure Concave_Uses_Hull (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Concave);
      Hull   : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Square);
   begin
      AUnit.Assertions.Assert
        (Close64 (Actual.Area, Hull.Area), "concave area matches hull");
      AUnit.Assertions.Assert
        (All_Points_Inside (Concave, Actual.Vertices),
         "concave points inside");
   end Concave_Uses_Hull;

   procedure Interior_Points_Ignored (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (With_Interior);
      Outer  : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Square);
   begin
      AUnit.Assertions.Assert
        (Close64 (Actual.Area, Outer.Area), "interior area unchanged");
      AUnit.Assertions.Assert
        (All_Points_Inside (With_Interior, Actual.Vertices),
         "interior points inside");
   end Interior_Points_Ignored;

   procedure Translated_Negative (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Actual   : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Translated);
      Expected : constant OpenCV.Geometry.Triangle_Vertices :=
        ((X => -10.0, Y => -6.0),
         (X => -6.0, Y => -6.0),
         (X => -10.0, Y => -3.0));
   begin
      AUnit.Assertions.Assert (Close64 (Actual.Area, 6.0), "translated area");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Actual.Vertices, Expected), "translated vertices");
      AUnit.Assertions.Assert
        (All_Points_Inside (Translated, Actual.Vertices),
         "translated points inside");
   end Translated_Negative;

   procedure Nonzero_Bounds (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour (11 .. 13) :=
        (11 => (X => 0, Y => 0),
         12 => (X => 4, Y => 0),
         13 => (X => 0, Y => 3));
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Points);
   begin
      AUnit.Assertions.Assert
        (Close64 (Actual.Area, 6.0), "nonzero bounds area");
      AUnit.Assertions.Assert
        (All_Points_Inside (Points, Actual.Vertices),
         "nonzero bounds points inside");
   end Nonzero_Bounds;

   procedure Reordered_Equivalent (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Direct : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Triangle);
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Reordered);
   begin
      AUnit.Assertions.Assert
        (Close64 (Actual.Area, Direct.Area), "reordered area");
      AUnit.Assertions.Assert
        (Same_Vertex_Set (Actual.Vertices, Direct.Vertices),
         "reordered vertices");
   end Reordered_Equivalent;

   procedure Input_Unchanged (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Original : constant OpenCV.Geometry.Contour := Square;
      pragma Warnings (Off, "could be declared constant");
      Points   : OpenCV.Geometry.Contour := Original;
      pragma Warnings (On, "could be declared constant");
      Unused   : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Points);
      pragma Unreferenced (Unused);
   begin
      AUnit.Assertions.Assert
        (Same_Contour (Points, Original), "input unchanged");
   end Input_Unchanged;

   procedure Vertices_Are_Binary32 (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Actual  : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Irregular);
      Rounded : Boolean := True;
   begin
      for Vertex of Actual.Vertices loop
         if not Vertex_Matches_Any_Source (Vertex, Irregular) then
            Rounded := False;
         end if;
      end loop;
      AUnit.Assertions.Assert
        (not Rounded, "vertices are not rounded source Points");
   end Vertices_Are_Binary32;

   procedure Empty_Is_Rejected (Test : in out Fixture) is
      pragma Unreferenced (Test);

      procedure Call is
         Empty  : OpenCV.Geometry.Contour (1 .. 0);
         Unused : OpenCV.Geometry.Enclosing_Triangle;
         pragma Unreferenced (Unused);
      begin
         Unused := OpenCV.Geometry.Minimum_Enclosing_Triangle (Empty);
      end Call;
   begin
      Assert_Raises_OpenCV_Error (Call'Access, "empty contour");
   end Empty_Is_Rejected;

   procedure One_Point (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour := (1 => (X => 2, Y => 3));
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Points);
   begin
      AUnit.Assertions.Assert (Close64 (Actual.Area, 0.0), "one-point area");
      AUnit.Assertions.Assert
        (Same_Vertex (Actual.Vertices (1), (X => 2.0, Y => 3.0)),
         "one-point v1");
      AUnit.Assertions.Assert
        (Same_Vertex (Actual.Vertices (2), (X => 2.0, Y => 3.0)),
         "one-point v2");
      AUnit.Assertions.Assert
        (Same_Vertex (Actual.Vertices (3), (X => 2.0, Y => 3.0)),
         "one-point v3");
   end One_Point;

   procedure Two_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 4, Y => 0));
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Points);
   begin
      AUnit.Assertions.Assert (Close64 (Actual.Area, 0.0), "two-point area");
      AUnit.Assertions.Assert
        (All_Points_Inside (Points, Actual.Vertices),
         "two-point vertices cover input");
   end Two_Points;

   procedure Three_Collinear (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 0, Y => 0), (X => 2, Y => 0), (X => 6, Y => 0));
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Points);
   begin
      AUnit.Assertions.Assert (Close64 (Actual.Area, 0.0), "collinear area");
      AUnit.Assertions.Assert
        (All_Points_Inside (Points, Actual.Vertices),
         "collinear points inside");
   end Three_Collinear;

   procedure Repeated_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points : constant OpenCV.Geometry.Contour :=
        ((X => 5, Y => 5), (X => 5, Y => 5), (X => 5, Y => 5));
      Actual : constant OpenCV.Geometry.Enclosing_Triangle :=
        OpenCV.Geometry.Minimum_Enclosing_Triangle (Points);
   begin
      AUnit.Assertions.Assert (Close64 (Actual.Area, 0.0), "repeated area");
      AUnit.Assertions.Assert
        (Same_Vertex (Actual.Vertices (1), (X => 5.0, Y => 5.0)),
         "repeated v1");
      AUnit.Assertions.Assert
        (Same_Vertex (Actual.Vertices (2), (X => 5.0, Y => 5.0)),
         "repeated v2");
      AUnit.Assertions.Assert
        (Same_Vertex (Actual.Vertices (3), (X => 5.0, Y => 5.0)),
         "repeated v3");
   end Repeated_Points;

   procedure C_ABI_Safety (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Points   : aliased C_API.Point_I32_Array :=
        ((X => 0, Y => 0),
         (X => 4, Y => 0),
         (X => 4, Y => 4),
         (X => 0, Y => 4));
      Unsafe_X : aliased C_API.Point_I32_Array :=
        ((X => Interfaces.Integer_32'First, Y => 0),
         (X => Interfaces.Integer_32'Last, Y => 0),
         (X => 0, Y => 1));
      Area     : aliased Interfaces.C.double := -1.0;
      Output   : aliased C_API.C_Triangle :=
        (V0_X => -1.0,
         V0_Y => -1.0,
         V1_X => -1.0,
         V1_Y => -1.0,
         V2_X => -1.0,
         V2_Y => -1.0);
      Status   : C_API.Status;

      procedure Assert_Zeroed (Message : String) is
      begin
         AUnit.Assertions.Assert (Area = 0.0, Message & " area");
         AUnit.Assertions.Assert
           (Output.V0_X = 0.0
            and then Output.V0_Y = 0.0
            and then Output.V1_X = 0.0
            and then Output.V1_Y = 0.0
            and then Output.V2_X = 0.0
            and then Output.V2_Y = 0.0,
            Message & " vertices");
      end Assert_Zeroed;

      procedure Assert_Rejected
        (Actual : C_API.Status; Needle, Message : String) is
      begin
         AUnit.Assertions.Assert
           (Actual = C_API.Error_Invalid_Argument, Message & " status");
         AUnit.Assertions.Assert
           (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, Needle) /= 0,
            Message & " diagnostic");
         Assert_Zeroed (Message);
      end Assert_Rejected;
   begin
      Status :=
        C_API.Min_Enclosing_Triangle
          (Points (Points'First)'Access, 4, null, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "null area status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "null") /= 0,
         "null area diagnostic");
      AUnit.Assertions.Assert
        (Output.V0_X = 0.0
         and then Output.V0_Y = 0.0
         and then Output.V1_X = 0.0
         and then Output.V1_Y = 0.0
         and then Output.V2_X = 0.0
         and then Output.V2_Y = 0.0,
         "null area vertices zeroed");

      Area := -1.0;
      Output :=
        (V0_X => -1.0,
         V0_Y => -1.0,
         V1_X => -1.0,
         V1_Y => -1.0,
         V2_X => -1.0,
         V2_Y => -1.0);
      Status :=
        C_API.Min_Enclosing_Triangle
          (Points (Points'First)'Access, 4, Area'Access, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument, "null triangle status");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (C_API.Last_Error_Message, "null") /= 0,
         "null triangle diagnostic");
      AUnit.Assertions.Assert (Area = 0.0, "null triangle area");
      AUnit.Assertions.Assert
        (Output.V0_X = -1.0
         and then Output.V0_Y = -1.0
         and then Output.V1_X = -1.0
         and then Output.V1_Y = -1.0
         and then Output.V2_X = -1.0
         and then Output.V2_Y = -1.0,
         "null triangle unused vertices");

      Area := -1.0;
      Output :=
        (V0_X => -1.0,
         V0_Y => -1.0,
         V1_X => -1.0,
         V1_Y => -1.0,
         V2_X => -1.0,
         V2_Y => -1.0);
      Status :=
        C_API.Min_Enclosing_Triangle (null, 4, Area'Access, Output'Access);
      Assert_Rejected (Status, "null", "null points");

      Area := -1.0;
      Output :=
        (V0_X => -1.0,
         V0_Y => -1.0,
         V1_X => -1.0,
         V1_Y => -1.0,
         V2_X => -1.0,
         V2_Y => -1.0);
      Status :=
        C_API.Min_Enclosing_Triangle
          (Points (Points'First)'Access, -1, Area'Access, Output'Access);
      Assert_Rejected (Status, "negative", "negative count");

      Area := -1.0;
      Output :=
        (V0_X => -1.0,
         V0_Y => -1.0,
         V1_X => -1.0,
         V1_Y => -1.0,
         V2_X => -1.0,
         V2_Y => -1.0);
      Status :=
        C_API.Min_Enclosing_Triangle
          (Unsafe_X (Unsafe_X'First)'Access, 3, Area'Access, Output'Access);
      Assert_Rejected (Status, "arithmetic", "overflow span");

      Area := -1.0;
      Output :=
        (V0_X => -1.0,
         V0_Y => -1.0,
         V1_X => -1.0,
         V1_Y => -1.0,
         V2_X => -1.0,
         V2_Y => -1.0);
      Status :=
        C_API.Min_Enclosing_Triangle (null, 0, Area'Access, Output'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_OpenCV, "empty native status");
      Assert_Zeroed ("empty native");

      Area := -1.0;
      Output :=
        (V0_X => -1.0,
         V0_Y => -1.0,
         V1_X => -1.0,
         V1_Y => -1.0,
         V2_X => -1.0,
         V2_Y => -1.0);
      Status :=
        C_API.Min_Enclosing_Triangle
          (Points (Points'First)'Access, 4, Area'Access, Output'Access);
      AUnit.Assertions.Assert (Status = C_API.Success, "recovery status");
      AUnit.Assertions.Assert (Area > 0.0, "recovery area");
   end C_ABI_Safety;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle ordinary", Ordinary_Triangle'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle square", Axis_Aligned_Square'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle irregular convex",
            Irregular_Convex'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle concave hull",
            Concave_Uses_Hull'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle interior points",
            Interior_Points_Ignored'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle translated negative",
            Translated_Negative'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle nonzero bounds",
            Nonzero_Bounds'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle reordered equivalent",
            Reordered_Equivalent'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle input unchanged",
            Input_Unchanged'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle binary32 vertices",
            Vertices_Are_Binary32'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle empty rejected",
            Empty_Is_Rejected'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle one point", One_Point'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle two points", Two_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle collinear", Three_Collinear'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle repeated", Repeated_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Minimum enclosing triangle C ABI safety", C_ABI_Safety'Access));
      return Result'Access;
   end Suite;

end Minimum_Enclosing_Triangle_Tests;
