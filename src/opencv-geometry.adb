with Ada.Exceptions;
with Ada.Numerics;
with Interfaces;
with Interfaces.C;
with OpenCV.Core.Float64_Access;
with OpenCV.Geometry.Internal.C_API;

package body OpenCV.Geometry is

   function To_C_Boolean (Value : Boolean) return Interfaces.Integer_32 is
   begin
      if Value then
         return 1;
      else
         return 0;
      end if;
   end To_C_Boolean;

   function To_C_Clockwise
     (Orientation : Hull_Orientation) return Interfaces.Integer_32 is
   begin
      case Orientation is
         when Clockwise        =>
            return 1;

         when Counterclockwise =>
            return 0;
      end case;
   end To_C_Clockwise;

   function To_C_Match_Method
     (Method : Shape_Match_Method) return Interfaces.Integer_32 is
   begin
      case Method is
         when Reciprocal_Log_Difference =>
            return Internal.C_API.Match_Shapes_Reciprocal_Log_Difference;

         when Log_Difference            =>
            return Internal.C_API.Match_Shapes_Log_Difference;

         when Relative_Log_Difference   =>
            return Internal.C_API.Match_Shapes_Relative_Log_Difference;
      end case;
   end To_C_Match_Method;

   function Pack_Contour
     (Points : Contour) return Internal.C_API.Point_I32_Array is
   begin
      if Points'Length > Natural (Interfaces.Integer_32'Last) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "contour point count exceeds C ABI range");
      end if;

      if Points'Length = 0 then
         declare
            Empty : Internal.C_API.Point_I32_Array (1 .. 0);
         begin
            return Empty;
         end;
      else
         declare
            Result : Internal.C_API.Point_I32_Array (0 .. Points'Length - 1);
            Index  : Natural := Result'First;
         begin
            for Point of Points loop
               Result (Index) :=
                 (X => Interfaces.Integer_32 (Point.X),
                  Y => Interfaces.Integer_32 (Point.Y));
               Index := Index + 1;
            end loop;
            return Result;
         end;
      end if;
   end Pack_Contour;

   procedure Raise_On_Error
     (Status : Internal.C_API.Status; Operation : String)
   is
      use type Internal.C_API.Status;

      Diagnostic : constant String := Internal.C_API.Last_Error_Message;
   begin
      if Status = Internal.C_API.Success then
         return;
      end if;

      if Diagnostic'Length = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, Operation & " failed");
      else
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " failed: " & Diagnostic);
      end if;
   end Raise_On_Error;

   function Contour_Area
     (Points : Contour; Oriented : Boolean := False)
      return OpenCV.Core.Float64_Value
   is
      Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Area   : aliased Interfaces.C.double := 0.0;
      Status : Internal.C_API.Status;
   begin
      if Packed'Length = 0 then
         Status :=
           Internal.C_API.Contour_Area
             (null, 0, To_C_Boolean (Oriented), Area'Access);
      else
         Status :=
           Internal.C_API.Contour_Area
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              To_C_Boolean (Oriented),
              Area'Access);
      end if;
      Raise_On_Error (Status, "contour area");
      return OpenCV.Core.Float64_Value (Area);
   end Contour_Area;

   function Arc_Length
     (Points : Contour; Closed : Boolean) return OpenCV.Core.Float64_Value
   is
      Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Length : aliased Interfaces.C.double := 0.0;
      Status : Internal.C_API.Status;
   begin
      if Packed'Length = 0 then
         Status :=
           Internal.C_API.Arc_Length
             (null, 0, To_C_Boolean (Closed), Length'Access);
      else
         Status :=
           Internal.C_API.Arc_Length
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              To_C_Boolean (Closed),
              Length'Access);
      end if;
      Raise_On_Error (Status, "arc length");
      return OpenCV.Core.Float64_Value (Length);
   end Arc_Length;

   function To_Public_Moments
     (Value : Internal.C_API.C_Moments) return Moments_Result is
   begin
      return
        (M_00  => OpenCV.Core.Float64_Value (Value.M00),
         M_10  => OpenCV.Core.Float64_Value (Value.M10),
         M_01  => OpenCV.Core.Float64_Value (Value.M01),
         M_20  => OpenCV.Core.Float64_Value (Value.M20),
         M_11  => OpenCV.Core.Float64_Value (Value.M11),
         M_02  => OpenCV.Core.Float64_Value (Value.M02),
         M_30  => OpenCV.Core.Float64_Value (Value.M30),
         M_21  => OpenCV.Core.Float64_Value (Value.M21),
         M_12  => OpenCV.Core.Float64_Value (Value.M12),
         M_03  => OpenCV.Core.Float64_Value (Value.M03),
         Mu_20 => OpenCV.Core.Float64_Value (Value.Mu20),
         Mu_11 => OpenCV.Core.Float64_Value (Value.Mu11),
         Mu_02 => OpenCV.Core.Float64_Value (Value.Mu02),
         Mu_30 => OpenCV.Core.Float64_Value (Value.Mu30),
         Mu_21 => OpenCV.Core.Float64_Value (Value.Mu21),
         Mu_12 => OpenCV.Core.Float64_Value (Value.Mu12),
         Mu_03 => OpenCV.Core.Float64_Value (Value.Mu03),
         Nu_20 => OpenCV.Core.Float64_Value (Value.Nu20),
         Nu_11 => OpenCV.Core.Float64_Value (Value.Nu11),
         Nu_02 => OpenCV.Core.Float64_Value (Value.Nu02),
         Nu_30 => OpenCV.Core.Float64_Value (Value.Nu30),
         Nu_21 => OpenCV.Core.Float64_Value (Value.Nu21),
         Nu_12 => OpenCV.Core.Float64_Value (Value.Nu12),
         Nu_03 => OpenCV.Core.Float64_Value (Value.Nu03));
   end To_Public_Moments;

   function To_C_Moments
     (Value : Moments_Result) return Internal.C_API.C_Moments is
   begin
      return
        (M00  => Interfaces.C.double (Value.M_00),
         M10  => Interfaces.C.double (Value.M_10),
         M01  => Interfaces.C.double (Value.M_01),
         M20  => Interfaces.C.double (Value.M_20),
         M11  => Interfaces.C.double (Value.M_11),
         M02  => Interfaces.C.double (Value.M_02),
         M30  => Interfaces.C.double (Value.M_30),
         M21  => Interfaces.C.double (Value.M_21),
         M12  => Interfaces.C.double (Value.M_12),
         M03  => Interfaces.C.double (Value.M_03),
         Mu20 => Interfaces.C.double (Value.Mu_20),
         Mu11 => Interfaces.C.double (Value.Mu_11),
         Mu02 => Interfaces.C.double (Value.Mu_02),
         Mu30 => Interfaces.C.double (Value.Mu_30),
         Mu21 => Interfaces.C.double (Value.Mu_21),
         Mu12 => Interfaces.C.double (Value.Mu_12),
         Mu03 => Interfaces.C.double (Value.Mu_03),
         Nu20 => Interfaces.C.double (Value.Nu_20),
         Nu11 => Interfaces.C.double (Value.Nu_11),
         Nu02 => Interfaces.C.double (Value.Nu_02),
         Nu30 => Interfaces.C.double (Value.Nu_30),
         Nu21 => Interfaces.C.double (Value.Nu_21),
         Nu12 => Interfaces.C.double (Value.Nu_12),
         Nu03 => Interfaces.C.double (Value.Nu_03));
   end To_C_Moments;

   function Compute_Moments (Points : Contour) return Moments_Result is
      Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Result : aliased Internal.C_API.C_Moments;
      Status : Internal.C_API.Status;
   begin
      if Packed'Length = 0 then
         Status := Internal.C_API.Contour_Moments (null, 0, Result'Access);
      else
         Status :=
           Internal.C_API.Contour_Moments
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              Result'Access);
      end if;
      Raise_On_Error (Status, "contour moments");
      return To_Public_Moments (Result);
   end Compute_Moments;

   function Is_Finite_C_Double (Value : Interfaces.C.double) return Boolean is
      pragma Suppress (Validity_Check);
      use type Interfaces.C.double;
   begin
      --  Public Float64_Value is finite-only. Inspect the raw C double
      --  before converting so Inf/NaN become OpenCV_Error, not an Ada
      --  validity failure.
      return
        Value'Valid
        and then Value = Value
        and then Value >= Interfaces.C.double (OpenCV.Core.Float64_Value'First)
        and then Value <= Interfaces.C.double (OpenCV.Core.Float64_Value'Last);
   end Is_Finite_C_Double;

   function To_Public_Float64
     (Value : Interfaces.C.double; Diagnostic : String)
      return OpenCV.Core.Float64_Value
   is
      pragma Suppress (Validity_Check);
   begin
      if not Is_Finite_C_Double (Value) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, Diagnostic);
      end if;
      return OpenCV.Core.Float64_Value (Value);
   end To_Public_Float64;

   function To_Public_Hu_Value
     (Value : Interfaces.C.double; Index : Hu_Moment_Index)
      return OpenCV.Core.Float64_Value is
   begin
      return
        To_Public_Float64
          (Value,
           "Hu moment"
           & Hu_Moment_Index'Image (Index)
           & " result is not finite");
   end To_Public_Hu_Value;

   function Hu_Moments (Moments : Moments_Result) return Hu_Moments_Result is
      --  Native Hu results may be Inf/NaN. Suppress Ada validity checks
      --  until To_Public_Hu_Value inspects the raw C doubles.
      pragma Suppress (Validity_Check);
      Packed : aliased Internal.C_API.C_Moments := To_C_Moments (Moments);
      Result : aliased Internal.C_API.C_Hu_Result :=
        (Hu_1 => 0.0,
         Hu_2 => 0.0,
         Hu_3 => 0.0,
         Hu_4 => 0.0,
         Hu_5 => 0.0,
         Hu_6 => 0.0,
         Hu_7 => 0.0);
      Status : Internal.C_API.Status;
   begin
      Status := Internal.C_API.Hu_Moments (Packed'Access, Result'Access);
      Raise_On_Error (Status, "Hu moments");
      return
        (1 => To_Public_Hu_Value (Result.Hu_1, 1),
         2 => To_Public_Hu_Value (Result.Hu_2, 2),
         3 => To_Public_Hu_Value (Result.Hu_3, 3),
         4 => To_Public_Hu_Value (Result.Hu_4, 4),
         5 => To_Public_Hu_Value (Result.Hu_5, 5),
         6 => To_Public_Hu_Value (Result.Hu_6, 6),
         7 => To_Public_Hu_Value (Result.Hu_7, 7));
   end Hu_Moments;

   function Unpack_Contour
     (Packed : Internal.C_API.Point_I32_Array; Count : Natural) return Contour
   is
   begin
      if Count = 0 then
         declare
            Empty : Contour (1 .. 0);
         begin
            return Empty;
         end;
      end if;

      declare
         Result : Contour (0 .. Count - 1);
         Index  : Natural := Result'First;
      begin
         for Offset in 0 .. Count - 1 loop
            Result (Index) :=
              (X =>
                 OpenCV.Core.Point_Coordinate
                   (Packed (Packed'First + Offset).X),
               Y =>
                 OpenCV.Core.Point_Coordinate
                   (Packed (Packed'First + Offset).Y));
            Index := Index + 1;
         end loop;
         return Result;
      end;
   end Unpack_Contour;

   function Convex_Hull
     (Points : Contour; Orientation : Hull_Orientation := Counterclockwise)
      return Contour
   is
      use type Interfaces.Integer_32;

      Packed    : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Count     : aliased Interfaces.Integer_32 := 0;
      Status    : Internal.C_API.Status;
      Clockwise : constant Interfaces.Integer_32 :=
        To_C_Clockwise (Orientation);
   begin
      if Packed'Length = 0 then
         Status :=
           Internal.C_API.Convex_Hull
             (null, 0, Clockwise, null, 0, Count'Access);
         Raise_On_Error (Status, "convex hull");
         return Unpack_Contour (Packed, 0);
      else
         declare
            Output : Internal.C_API.Point_I32_Array (0 .. Packed'Length - 1);
         begin
            Status :=
              Internal.C_API.Convex_Hull
                (Packed (Packed'First)'Access,
                 Interfaces.Integer_32 (Packed'Length),
                 Clockwise,
                 Output (Output'First)'Access,
                 Interfaces.Integer_32 (Output'Length),
                 Count'Access);
            Raise_On_Error (Status, "convex hull");
            if Count < 0 then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "convex hull failed: negative hull count");
            end if;
            if Natural (Count) > Output'Length then
               Ada.Exceptions.Raise_Exception
                 (OpenCV.OpenCV_Error'Identity,
                  "convex hull failed: hull count exceeds capacity");
            end if;
            return Unpack_Contour (Output, Natural (Count));
         end;
      end if;
   end Convex_Hull;

   function Approximate_Curve
     (Points : Contour; Epsilon : OpenCV.Core.Float64_Value; Closed : Boolean)
      return Contour
   is
      use type OpenCV.Core.Float64_Value;
   begin
      if not Epsilon'Valid or else Epsilon < 0.0 or else Epsilon >= 1.0E30 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "approximate curve epsilon must be in the range "
            & "0.0 <= epsilon < 1.0E30");
      end if;

      declare
         use type Interfaces.Integer_32;

         Packed      : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
         Count       : aliased Interfaces.Integer_32 := 0;
         Status      : Internal.C_API.Status;
         Closed_Flag : constant Interfaces.Integer_32 := To_C_Boolean (Closed);
      begin
         if Packed'Length = 0 then
            Status :=
              Internal.C_API.Approximate_Curve
                (null,
                 0,
                 Interfaces.C.double (Epsilon),
                 Closed_Flag,
                 null,
                 0,
                 Count'Access);
            Raise_On_Error (Status, "approximate curve");
            return Unpack_Contour (Packed, 0);
         else
            declare
               Output :
                 Internal.C_API.Point_I32_Array (0 .. Packed'Length - 1);
            begin
               Status :=
                 Internal.C_API.Approximate_Curve
                   (Packed (Packed'First)'Access,
                    Interfaces.Integer_32 (Packed'Length),
                    Interfaces.C.double (Epsilon),
                    Closed_Flag,
                    Output (Output'First)'Access,
                    Interfaces.Integer_32 (Output'Length),
                    Count'Access);
               Raise_On_Error (Status, "approximate curve");
               if Count < 0 then
                  Ada.Exceptions.Raise_Exception
                    (OpenCV.OpenCV_Error'Identity,
                     "approximate curve failed: negative point count");
               end if;
               if Natural (Count) > Output'Length then
                  Ada.Exceptions.Raise_Exception
                    (OpenCV.OpenCV_Error'Identity,
                     "approximate curve failed: count exceeds capacity");
               end if;
               return Unpack_Contour (Output, Natural (Count));
            end;
         end if;
      end;
   end Approximate_Curve;

   function To_Public_Rect
     (Value : Internal.C_API.Rect_I32) return OpenCV.Core.Rect
   is
      use type Interfaces.Integer_32;
   begin
      if Value.Width < 0 or else Value.Height < 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "bounding rect cannot be represented as OpenCV.Core.Rect");
      end if;

      return
        (X      => OpenCV.Core.Point_Coordinate (Value.X),
         Y      => OpenCV.Core.Point_Coordinate (Value.Y),
         Width  => OpenCV.Core.Size_Coordinate (Value.Width),
         Height => OpenCV.Core.Size_Coordinate (Value.Height));
   end To_Public_Rect;

   function Bounding_Rect (Points : Contour) return OpenCV.Core.Rect is
      Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Result : aliased Internal.C_API.Rect_I32 :=
        (X => 0, Y => 0, Width => 0, Height => 0);
      Status : Internal.C_API.Status;
   begin
      if Packed'Length = 0 then
         Status := Internal.C_API.Bounding_Rect (null, 0, Result'Access);
      else
         Status :=
           Internal.C_API.Bounding_Rect
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              Result'Access);
      end if;
      Raise_On_Error (Status, "bounding rect");
      return To_Public_Rect (Result);
   end Bounding_Rect;

   function Is_Convex (Points : Contour) return Boolean is
      Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Result : aliased Interfaces.Integer_32 := 0;
      Status : Internal.C_API.Status;
   begin
      if Packed'Length = 0 then
         Status := Internal.C_API.Is_Convex (null, 0, Result'Access);
      else
         Status :=
           Internal.C_API.Is_Convex
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              Result'Access);
      end if;
      Raise_On_Error (Status, "is convex");

      case Result is
         when 0      =>
            return False;

         when 1      =>
            return True;

         when others =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "is convex failed: invalid Boolean encoding");
      end case;
   end Is_Convex;

   function Match_Shapes
     (Left, Right : Contour; Method : Shape_Match_Method)
      return OpenCV.Core.Float64_Value
   is
      --  Native scores may be Inf/NaN. Suppress Ada validity checks until
      --  To_Public_Float64 inspects the raw C double.
      pragma Suppress (Validity_Check);
      Packed_Left  : Internal.C_API.Point_I32_Array := Pack_Contour (Left);
      Packed_Right : Internal.C_API.Point_I32_Array := Pack_Contour (Right);
      Score        : aliased Interfaces.C.double := 0.0;
      Status       : Internal.C_API.Status;
   begin
      if Packed_Left'Length = 0 and then Packed_Right'Length = 0 then
         Status :=
           Internal.C_API.Match_Shapes
             (null, 0, null, 0, To_C_Match_Method (Method), Score'Access);
      elsif Packed_Left'Length = 0 then
         Status :=
           Internal.C_API.Match_Shapes
             (null,
              0,
              Packed_Right (Packed_Right'First)'Access,
              Interfaces.Integer_32 (Packed_Right'Length),
              To_C_Match_Method (Method),
              Score'Access);
      elsif Packed_Right'Length = 0 then
         Status :=
           Internal.C_API.Match_Shapes
             (Packed_Left (Packed_Left'First)'Access,
              Interfaces.Integer_32 (Packed_Left'Length),
              null,
              0,
              To_C_Match_Method (Method),
              Score'Access);
      else
         Status :=
           Internal.C_API.Match_Shapes
             (Packed_Left (Packed_Left'First)'Access,
              Interfaces.Integer_32 (Packed_Left'Length),
              Packed_Right (Packed_Right'First)'Access,
              Interfaces.Integer_32 (Packed_Right'Length),
              To_C_Match_Method (Method),
              Score'Access);
      end if;
      Raise_On_Error (Status, "match shapes");
      return To_Public_Float64 (Score, "Match_Shapes result is not finite");
   end Match_Shapes;

   function Call_Point_Polygon_Test
     (Points           : Contour;
      Query            : OpenCV.Core.Float32_Point;
      Measure_Distance : Interfaces.Integer_32) return Interfaces.C.double
   is
      pragma Suppress (Validity_Check);
      Packed  : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Result  : aliased Interfaces.C.double := 0.0;
      Status  : Internal.C_API.Status;
      Query_X : constant Interfaces.C.C_float :=
        Interfaces.C.C_float (Query.X);
      Query_Y : constant Interfaces.C.C_float :=
        Interfaces.C.C_float (Query.Y);
   begin
      if Packed'Length = 0 then
         Status :=
           Internal.C_API.Point_Polygon_Test
             (null, 0, Query_X, Query_Y, Measure_Distance, Result'Access);
      else
         Status :=
           Internal.C_API.Point_Polygon_Test
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              Query_X,
              Query_Y,
              Measure_Distance,
              Result'Access);
      end if;
      Raise_On_Error (Status, "point polygon test");
      return Result;
   end Call_Point_Polygon_Test;

   function Locate_Point
     (Points : Contour; Query : OpenCV.Core.Float32_Point)
      return Contour_Point_Location
   is
      pragma Suppress (Validity_Check);
      use type Interfaces.C.double;
      Result : constant Interfaces.C.double :=
        Call_Point_Polygon_Test
          (Points, Query, Internal.C_API.Point_Polygon_Classify);
   begin
      if Result = -1.0 then
         return Outside_Contour;
      elsif Result = 0.0 then
         return On_Contour_Boundary;
      elsif Result = 1.0 then
         return Inside_Contour;
      else
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "point polygon classification result is invalid");
      end if;
   end Locate_Point;

   function Signed_Distance_To_Contour
     (Points : Contour; Query : OpenCV.Core.Float32_Point)
      return OpenCV.Core.Float64_Value
   is
      Result : constant Interfaces.C.double :=
        Call_Point_Polygon_Test
          (Points, Query, Internal.C_API.Point_Polygon_Distance);
   begin
      return
        To_Public_Float64
          (Result, "Signed_Distance_To_Contour result is not finite");
   end Signed_Distance_To_Contour;

   function Is_Finite_C_Float (Value : Interfaces.C.C_float) return Boolean is
      pragma Suppress (Validity_Check);
      use type Interfaces.C.C_float;
   begin
      --  Public Float32_Value is finite-only. Inspect the raw C float
      --  before converting so Inf/NaN become OpenCV_Error, not an Ada
      --  validity failure.
      return
        Value'Valid
        and then Value = Value
        and then Value
                 >= Interfaces.C.C_float (OpenCV.Core.Float32_Value'First)
        and then Value
                 <= Interfaces.C.C_float (OpenCV.Core.Float32_Value'Last);
   end Is_Finite_C_Float;

   function To_Public_Float32
     (Value : Interfaces.C.C_float; Diagnostic : String)
      return OpenCV.Core.Float32_Value
   is
      pragma Suppress (Validity_Check);
   begin
      if not Is_Finite_C_Float (Value) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, Diagnostic);
      end if;
      return OpenCV.Core.Float32_Value (Value);
   end To_Public_Float32;

   function To_Public_Enclosing_Circle
     (Value : Internal.C_API.C_Enclosing_Circle) return Enclosing_Circle
   is
      pragma Suppress (Validity_Check);
      use type OpenCV.Core.Float32_Value;
      Center_X : constant OpenCV.Core.Float32_Value :=
        To_Public_Float32
          (Value.Center_X, "enclosing circle center X is not finite");
      Center_Y : constant OpenCV.Core.Float32_Value :=
        To_Public_Float32
          (Value.Center_Y, "enclosing circle center Y is not finite");
      Radius   : constant OpenCV.Core.Float32_Value :=
        To_Public_Float32
          (Value.Radius, "enclosing circle radius is not finite");
   begin
      if Radius < 0.0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "enclosing circle radius is negative");
      end if;
      return (Center => (X => Center_X, Y => Center_Y), Radius => Radius);
   end To_Public_Enclosing_Circle;

   function Minimum_Enclosing_Circle (Points : Contour) return Enclosing_Circle
   is
      pragma Suppress (Validity_Check);
      Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Result : aliased Internal.C_API.C_Enclosing_Circle :=
        (Center_X => 0.0, Center_Y => 0.0, Radius => 0.0);
      Status : Internal.C_API.Status;
   begin
      if Packed'Length = 0 then
         Status :=
           Internal.C_API.Min_Enclosing_Circle (null, 0, Result'Access);
      else
         Status :=
           Internal.C_API.Min_Enclosing_Circle
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              Result'Access);
      end if;
      Raise_On_Error (Status, "minimum enclosing circle");
      return To_Public_Enclosing_Circle (Result);
   end Minimum_Enclosing_Circle;

   procedure Validate_Get_Rotation_Matrix_2D
     (Center : OpenCV.Core.Float32_Point;
      Angle  : OpenCV.Core.Float64_Value;
      Scale  : OpenCV.Core.Float64_Value)
   is
      use type OpenCV.Core.Float32_Value;
      use type OpenCV.Core.Float64_Value;
   begin
      if Center.X /= Center.X
        or else Center.X > OpenCV.Core.Float32_Value'Last
        or else Center.X < OpenCV.Core.Float32_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Rotation_Matrix_2D requires a finite Center.X");
      end if;

      if Center.Y /= Center.Y
        or else Center.Y > OpenCV.Core.Float32_Value'Last
        or else Center.Y < OpenCV.Core.Float32_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Rotation_Matrix_2D requires a finite Center.Y");
      end if;

      if Angle /= Angle
        or else Angle > OpenCV.Core.Float64_Value'Last
        or else Angle < OpenCV.Core.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Rotation_Matrix_2D requires a finite Angle");
      end if;

      if Scale /= Scale
        or else Scale > OpenCV.Core.Float64_Value'Last
        or else Scale < OpenCV.Core.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Rotation_Matrix_2D requires a finite Scale");
      end if;
   end Validate_Get_Rotation_Matrix_2D;

   function Reduced_Degrees
     (Angle : OpenCV.Core.Float64_Value; Units : OpenCV.Core.Angle_Unit)
      return OpenCV.Core.Float64_Value
   is
      use type OpenCV.Core.Angle_Unit;
      use type OpenCV.Core.Float64_Value;
      Full_Turn : OpenCV.Core.Float64_Value;
      Reduced   : OpenCV.Core.Float64_Value;
   begin
      if Units = OpenCV.Core.Degrees then
         Full_Turn := 360.0;
         return OpenCV.Core.Float64_Value'Remainder (Angle, Full_Turn);
      end if;

      Full_Turn :=
        OpenCV.Core.Float64_Value (2.0)
        * OpenCV.Core.Float64_Value (Ada.Numerics.Pi);
      Reduced := OpenCV.Core.Float64_Value'Remainder (Angle, Full_Turn);
      return
        Reduced
        * (OpenCV.Core.Float64_Value (180.0)
           / OpenCV.Core.Float64_Value (Ada.Numerics.Pi));
   end Reduced_Degrees;

   function Get_Rotation_Matrix_2D
     (Center : OpenCV.Core.Float32_Point;
      Angle  : OpenCV.Core.Float64_Value;
      Scale  : OpenCV.Core.Float64_Value := 1.0;
      Units  : OpenCV.Core.Angle_Unit := OpenCV.Core.Degrees)
      return OpenCV.Core.Mat
   is
      Degrees : OpenCV.Core.Float64_Value;
      Result  : aliased Internal.C_API.C_Affine_2x3_F64 :=
        (M00 => 0.0,
         M01 => 0.0,
         M02 => 0.0,
         M10 => 0.0,
         M11 => 0.0,
         M12 => 0.0);
      Status  : Internal.C_API.Status;
      Matrix  : OpenCV.Core.Mat;
   begin
      Validate_Get_Rotation_Matrix_2D (Center, Angle, Scale);
      Degrees := Reduced_Degrees (Angle, Units);
      Status :=
        Internal.C_API.Get_Rotation_Matrix_2D
          (Interfaces.C.C_float (Center.X),
           Interfaces.C.C_float (Center.Y),
           Interfaces.C.double (Degrees),
           Interfaces.C.double (Scale),
           Result'Access);
      Raise_On_Error (Status, "Get_Rotation_Matrix_2D");

      Matrix := OpenCV.Core.Create (2, 3, (OpenCV.Core.Float64, 1));
      OpenCV.Core.Float64_Access.Set
        (Matrix, 0, 0, To_Public_Float64 (Result.M00, "M00 is not finite"));
      OpenCV.Core.Float64_Access.Set
        (Matrix, 0, 1, To_Public_Float64 (Result.M01, "M01 is not finite"));
      OpenCV.Core.Float64_Access.Set
        (Matrix, 0, 2, To_Public_Float64 (Result.M02, "M02 is not finite"));
      OpenCV.Core.Float64_Access.Set
        (Matrix, 1, 0, To_Public_Float64 (Result.M10, "M10 is not finite"));
      OpenCV.Core.Float64_Access.Set
        (Matrix, 1, 1, To_Public_Float64 (Result.M11, "M11 is not finite"));
      OpenCV.Core.Float64_Access.Set
        (Matrix, 1, 2, To_Public_Float64 (Result.M12, "M12 is not finite"));
      return Matrix;
   end Get_Rotation_Matrix_2D;
end OpenCV.Geometry;
