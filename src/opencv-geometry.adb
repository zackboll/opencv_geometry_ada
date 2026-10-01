with Ada.Exceptions;
with Ada.Numerics;
with Interfaces;
with Interfaces.C;
with OpenCV.Core.Float64_Access;
with OpenCV.Geometry.Internal.C_API;
with OpenCV.Geometry.Internal.Convexity;
with OpenCV.Geometry.Internal.Float32_Points;
with OpenCV.Geometry.Internal.Intersection;
with OpenCV.Geometry.Internal.Transforms;

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
      return OpenCV.Float64_Value
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
      return OpenCV.Float64_Value (Area);
   end Contour_Area;

   function Arc_Length
     (Points : Contour; Closed : Boolean) return OpenCV.Float64_Value
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
      return OpenCV.Float64_Value (Length);
   end Arc_Length;

   function To_Public_Moments
     (Value : Internal.C_API.C_Moments) return Moments_Result is
   begin
      return
        (M_00  => OpenCV.Float64_Value (Value.M00),
         M_10  => OpenCV.Float64_Value (Value.M10),
         M_01  => OpenCV.Float64_Value (Value.M01),
         M_20  => OpenCV.Float64_Value (Value.M20),
         M_11  => OpenCV.Float64_Value (Value.M11),
         M_02  => OpenCV.Float64_Value (Value.M02),
         M_30  => OpenCV.Float64_Value (Value.M30),
         M_21  => OpenCV.Float64_Value (Value.M21),
         M_12  => OpenCV.Float64_Value (Value.M12),
         M_03  => OpenCV.Float64_Value (Value.M03),
         Mu_20 => OpenCV.Float64_Value (Value.Mu20),
         Mu_11 => OpenCV.Float64_Value (Value.Mu11),
         Mu_02 => OpenCV.Float64_Value (Value.Mu02),
         Mu_30 => OpenCV.Float64_Value (Value.Mu30),
         Mu_21 => OpenCV.Float64_Value (Value.Mu21),
         Mu_12 => OpenCV.Float64_Value (Value.Mu12),
         Mu_03 => OpenCV.Float64_Value (Value.Mu03),
         Nu_20 => OpenCV.Float64_Value (Value.Nu20),
         Nu_11 => OpenCV.Float64_Value (Value.Nu11),
         Nu_02 => OpenCV.Float64_Value (Value.Nu02),
         Nu_30 => OpenCV.Float64_Value (Value.Nu30),
         Nu_21 => OpenCV.Float64_Value (Value.Nu21),
         Nu_12 => OpenCV.Float64_Value (Value.Nu12),
         Nu_03 => OpenCV.Float64_Value (Value.Nu03));
   end To_Public_Moments;

   function To_C_Moments
     (Value : Moments_Result) return Internal.C_API.C_Moments
   is
      --  A caller's Value may hold Inf/NaN; Hu_Moments rejects them after
      --  packing.
      pragma Suppress (Validity_Check);
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
        and then Value >= Interfaces.C.double (OpenCV.Float64_Value'First)
        and then Value <= Interfaces.C.double (OpenCV.Float64_Value'Last);
   end Is_Finite_C_Double;

   function To_Public_Float64
     (Value : Interfaces.C.double; Diagnostic : String)
      return OpenCV.Float64_Value
   is
      pragma Suppress (Validity_Check);
   begin
      if not Is_Finite_C_Double (Value) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, Diagnostic);
      end if;
      return OpenCV.Float64_Value (Value);
   end To_Public_Float64;

   function To_Public_Hu_Value
     (Value : Interfaces.C.double; Index : Hu_Moment_Index)
      return OpenCV.Float64_Value
   is
      --  Value may be Inf/NaN; To_Public_Float64 inspects it.
      pragma Suppress (Validity_Check);
   begin
      return
        To_Public_Float64
          (Value,
           "Hu moment"
           & Hu_Moment_Index'Image (Index)
           & " result is not finite");
   end To_Public_Hu_Value;

   --  True when every field of Packed is finite.
   function All_Finite (Packed : Internal.C_API.C_Moments) return Boolean is
      pragma Suppress (Validity_Check);
   begin
      return
        Is_Finite_C_Double (Packed.M00)
        and then Is_Finite_C_Double (Packed.M10)
        and then Is_Finite_C_Double (Packed.M01)
        and then Is_Finite_C_Double (Packed.M20)
        and then Is_Finite_C_Double (Packed.M11)
        and then Is_Finite_C_Double (Packed.M02)
        and then Is_Finite_C_Double (Packed.M30)
        and then Is_Finite_C_Double (Packed.M21)
        and then Is_Finite_C_Double (Packed.M12)
        and then Is_Finite_C_Double (Packed.M03)
        and then Is_Finite_C_Double (Packed.Mu20)
        and then Is_Finite_C_Double (Packed.Mu11)
        and then Is_Finite_C_Double (Packed.Mu02)
        and then Is_Finite_C_Double (Packed.Mu30)
        and then Is_Finite_C_Double (Packed.Mu21)
        and then Is_Finite_C_Double (Packed.Mu12)
        and then Is_Finite_C_Double (Packed.Mu03)
        and then Is_Finite_C_Double (Packed.Nu20)
        and then Is_Finite_C_Double (Packed.Nu11)
        and then Is_Finite_C_Double (Packed.Nu02)
        and then Is_Finite_C_Double (Packed.Nu30)
        and then Is_Finite_C_Double (Packed.Nu21)
        and then Is_Finite_C_Double (Packed.Nu12)
        and then Is_Finite_C_Double (Packed.Nu03);
   end All_Finite;

   function Hu_Moments (Moments : Moments_Result) return Hu_Moments_Result is
      --  Moments and the native Hu results may be Inf/NaN. Suppress Ada
      --  validity checks until All_Finite and To_Public_Hu_Value inspect
      --  the raw C doubles.
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
      if not All_Finite (Packed) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Hu_Moments requires finite Moments fields");
      end if;
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
              (X => OpenCV.Point_Coordinate (Packed (Packed'First + Offset).X),
               Y =>
                 OpenCV.Point_Coordinate (Packed (Packed'First + Offset).Y));
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

   function Empty_Point_Indices return Point_Index_Array is
      Empty : Point_Index_Array (1 .. 0);
   begin
      return Empty;
   end Empty_Point_Indices;

   function Empty_Convexity_Defects return Convexity_Defect_Array is
      Empty : Convexity_Defect_Array (1 .. 0);
   begin
      return Empty;
   end Empty_Convexity_Defects;

   --  Converts a native zero-based offset to its index in Points'Range.
   --  Native results outside Points raise OpenCV_Error instead of producing
   --  an invalid public index.
   function To_Public_Point_Index
     (Points : Contour; Offset : Interfaces.Integer_32; Operation : String)
      return Natural is
   begin
      if Points'Length = 0
        or else not Internal.Convexity.Is_Native_Offset
                      (Points'First, Points'Last, Offset)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation
            & " failed: native index"
            & Interfaces.Integer_32'Image (Offset)
            & " is outside the contour");
      end if;
      return
        Internal.Convexity.To_Point_Index (Points'First, Points'Last, Offset);
   end To_Public_Point_Index;

   function Convex_Hull_Indices
     (Points : Contour; Orientation : Hull_Orientation := Counterclockwise)
      return Point_Index_Array
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
           Internal.C_API.Convex_Hull_Indices
             (null, 0, Clockwise, null, 0, Count'Access);
         Raise_On_Error (Status, "convex hull indices");
         return Empty_Point_Indices;
      end if;

      declare
         --  Hull vertices are distinct source points, so the hull count is
         --  at most Points'Length.
         Output : Internal.C_API.Int32_Array (0 .. Packed'Length - 1);
      begin
         Status :=
           Internal.C_API.Convex_Hull_Indices
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              Clockwise,
              Output (Output'First)'Access,
              Interfaces.Integer_32 (Output'Length),
              Count'Access);
         Raise_On_Error (Status, "convex hull indices");
         if Count < 0 then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "convex hull indices failed: negative hull count");
         end if;
         if Natural (Count) > Output'Length then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "convex hull indices failed: hull count exceeds capacity");
         end if;
         if Count = 0 then
            return Empty_Point_Indices;
         end if;

         declare
            Result : Point_Index_Array (0 .. Natural (Count) - 1);
         begin
            for Position in Result'Range loop
               Result (Position) :=
                 To_Public_Point_Index
                   (Points,
                    Output (Output'First + Position),
                    "convex hull indices");
            end loop;
            return Result;
         end;
      end;
   end Convex_Hull_Indices;

   --  Public semantic policy for a hull passed to convexity defects: every
   --  index in Points'Range, and the strictly monotonic order that native
   --  convexityDefects traverses. Native OpenCV 4.6, 4.10, and 5.0 accept
   --  exactly the strictly monotonic distinct-index hulls, but also accept
   --  some hulls with repeated indices, which this policy rejects.
   procedure Validate_Defect_Hull
     (Points : Contour; Hull : Point_Index_Array; Computed : Boolean) is
   begin
      for Index of Hull loop
         if Index not in Points'Range then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "convexity defects hull index"
               & Natural'Image (Index)
               & " is outside Points'Range");
         end if;
      end loop;

      if not Internal.Convexity.Is_Strictly_Monotonic (Hull) then
         if Computed then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "convexity defects failed: convex hull indices are not "
               & "monotonic; Points may be self-intersecting");
         else
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "convexity defects hull indices must be strictly increasing "
               & "or strictly decreasing");
         end if;
      end if;
   end Validate_Defect_Hull;

   function To_Public_Defects
     (Points : Contour;
      Output : Internal.C_API.C_Convexity_Defect_Array;
      Count  : Natural) return Convexity_Defect_Array
   is
      use type OpenCV.Float64_Value;

      Scale : constant OpenCV.Float64_Value :=
        OpenCV.Float64_Value (Internal.Convexity.Fixed_Point_Depth_Scale);
   begin
      if Count = 0 then
         return Empty_Convexity_Defects;
      end if;

      declare
         Result : Convexity_Defect_Array (0 .. Count - 1);
      begin
         for Position in Result'Range loop
            declare
               Native : Internal.C_API.C_Convexity_Defect renames
                 Output (Output'First + Position);
            begin
               Result (Position) :=
                 (Start_Index    =>
                    To_Public_Point_Index
                      (Points, Native.Start_Index, "convexity defects"),
                  End_Index      =>
                    To_Public_Point_Index
                      (Points, Native.End_Index, "convexity defects"),
                  Farthest_Index =>
                    To_Public_Point_Index
                      (Points, Native.Farthest_Index, "convexity defects"),
                  Depth          =>
                    OpenCV.Float64_Value (Native.Fixed_Point_Depth) / Scale);
            end;
         end loop;
         return Result;
      end;
   end To_Public_Defects;

   --  Calls native convexityDefects for a validated Hull when Points has
   --  more than three points and Hull at least three indices.
   function Native_Convexity_Defects
     (Points : Contour; Hull : Point_Index_Array) return Convexity_Defect_Array
   is
      use type Interfaces.Integer_32;

      Packed      : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Native_Hull : Internal.C_API.Int32_Array (0 .. Hull'Length - 1);
      --  Native convexityDefects appends at most one defect per hull index,
      --  and a validated Hull has at most Points'Length indices.
      Output      :
        Internal.C_API.C_Convexity_Defect_Array (0 .. Hull'Length - 1);
      Count       : aliased Interfaces.Integer_32 := 0;
      Status      : Internal.C_API.Status;
   begin
      if not Internal.Convexity.Defect_Extent_Is_Safe
               (Internal.Convexity.Bounds_Of (Points))
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "convexity defects contour spans exceed the native fixed-point "
            & "depth range: Width**2 + Height**2 must not exceed "
            & "8388607**2");
      end if;

      for Position in Hull'Range loop
         Native_Hull (Position - Hull'First) :=
           Internal.Convexity.To_Native_Offset
             (Points'First, Points'Last, Hull (Position));
      end loop;

      Status :=
        Internal.C_API.Convexity_Defects
          (Packed (Packed'First)'Access,
           Interfaces.Integer_32 (Packed'Length),
           Native_Hull (Native_Hull'First)'Access,
           Interfaces.Integer_32 (Native_Hull'Length),
           Output (Output'First)'Access,
           Interfaces.Integer_32 (Output'Length),
           Count'Access);
      Raise_On_Error (Status, "convexity defects");
      if Count < 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "convexity defects failed: negative defect count");
      end if;
      if Natural (Count) > Output'Length then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "convexity defects failed: defect count exceeds capacity");
      end if;
      return To_Public_Defects (Points, Output, Natural (Count));
   end Native_Convexity_Defects;

   function Convexity_Defects_For_Hull
     (Points : Contour; Hull : Point_Index_Array; Computed : Boolean)
      return Convexity_Defect_Array is
   begin
      Validate_Defect_Hull (Points, Hull, Computed);
      --  Native convexityDefects returns no defects for at most three
      --  contour points or fewer than three hull indices.
      if Points'Length <= 3 or else Hull'Length < 3 then
         return Empty_Convexity_Defects;
      end if;
      return Native_Convexity_Defects (Points, Hull);
   end Convexity_Defects_For_Hull;

   function Convexity_Defects
     (Points : Contour; Hull : Point_Index_Array) return Convexity_Defect_Array
   is
   begin
      return Convexity_Defects_For_Hull (Points, Hull, Computed => False);
   end Convexity_Defects;

   function Convexity_Defects (Points : Contour) return Convexity_Defect_Array
   is
   begin
      if Points'Length <= 3 then
         return Empty_Convexity_Defects;
      end if;
      return
        Convexity_Defects_For_Hull
          (Points, Convex_Hull_Indices (Points), Computed => True);
   end Convexity_Defects;

   function Approximate_Curve
     (Points : Contour; Epsilon : OpenCV.Float64_Value; Closed : Boolean)
      return Contour
   is
      use type OpenCV.Float64_Value;
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

   function To_Public_Rect (Value : Internal.C_API.Rect_I32) return OpenCV.Rect
   is
      use type Interfaces.Integer_32;
   begin
      if Value.Width < 0 or else Value.Height < 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "bounding rect cannot be represented as OpenCV.Rect");
      end if;

      return
        (X      => OpenCV.Point_Coordinate (Value.X),
         Y      => OpenCV.Point_Coordinate (Value.Y),
         Width  => OpenCV.Size_Coordinate (Value.Width),
         Height => OpenCV.Size_Coordinate (Value.Height));
   end To_Public_Rect;

   function Bounding_Rect (Points : Contour) return OpenCV.Rect is
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
      return OpenCV.Float64_Value
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
      Query            : OpenCV.Float32_Point;
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
     (Points : Contour; Query : OpenCV.Float32_Point)
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
     (Points : Contour; Query : OpenCV.Float32_Point)
      return OpenCV.Float64_Value
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
        and then Value >= Interfaces.C.C_float (OpenCV.Float32_Value'First)
        and then Value <= Interfaces.C.C_float (OpenCV.Float32_Value'Last);
   end Is_Finite_C_Float;

   function To_Public_Float32
     (Value : Interfaces.C.C_float; Diagnostic : String)
      return OpenCV.Float32_Value
   is
      pragma Suppress (Validity_Check);
   begin
      if not Is_Finite_C_Float (Value) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, Diagnostic);
      end if;
      return OpenCV.Float32_Value (Value);
   end To_Public_Float32;

   function To_Public_Enclosing_Circle
     (Value : Internal.C_API.C_Enclosing_Circle) return Enclosing_Circle
   is
      pragma Suppress (Validity_Check);
      use type OpenCV.Float32_Value;
      Center_X : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.Center_X, "enclosing circle center X is not finite");
      Center_Y : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.Center_Y, "enclosing circle center Y is not finite");
      Radius   : constant OpenCV.Float32_Value :=
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

   function To_Public_Enclosing_Triangle
     (Area : Interfaces.C.double; Value : Internal.C_API.C_Triangle)
      return Enclosing_Triangle
   is
      pragma Suppress (Validity_Check);
      use type OpenCV.Float64_Value;
      Public_Area : constant OpenCV.Float64_Value :=
        To_Public_Float64 (Area, "enclosing triangle area is not finite");
      V0_X        : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.V0_X, "enclosing triangle vertex 1 X is not finite");
      V0_Y        : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.V0_Y, "enclosing triangle vertex 1 Y is not finite");
      V1_X        : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.V1_X, "enclosing triangle vertex 2 X is not finite");
      V1_Y        : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.V1_Y, "enclosing triangle vertex 2 Y is not finite");
      V2_X        : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.V2_X, "enclosing triangle vertex 3 X is not finite");
      V2_Y        : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.V2_Y, "enclosing triangle vertex 3 Y is not finite");
   begin
      if Public_Area < 0.0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "enclosing triangle area is negative");
      end if;
      return
        (Area     => Public_Area,
         Vertices =>
           (1 => (X => V0_X, Y => V0_Y),
            2 => (X => V1_X, Y => V1_Y),
            3 => (X => V2_X, Y => V2_Y)));
   end To_Public_Enclosing_Triangle;

   function Minimum_Enclosing_Triangle
     (Points : Contour) return Enclosing_Triangle
   is
      pragma Suppress (Validity_Check);
      Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Area   : aliased Interfaces.C.double := 0.0;
      Result : aliased Internal.C_API.C_Triangle :=
        (V0_X => 0.0,
         V0_Y => 0.0,
         V1_X => 0.0,
         V1_Y => 0.0,
         V2_X => 0.0,
         V2_Y => 0.0);
      Status : Internal.C_API.Status;
   begin
      if Packed'Length = 0 then
         Status :=
           Internal.C_API.Min_Enclosing_Triangle
             (null, 0, Area'Access, Result'Access);
      else
         Status :=
           Internal.C_API.Min_Enclosing_Triangle
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              Area'Access,
              Result'Access);
      end if;
      Raise_On_Error (Status, "minimum enclosing triangle");
      return To_Public_Enclosing_Triangle (Area, Result);
   end Minimum_Enclosing_Triangle;

   function Is_Finite_Public_Float32
     (Value : OpenCV.Float32_Value) return Boolean
   is
      pragma Suppress (Validity_Check);
      use type OpenCV.Float32_Value;
   begin
      return
        Value = Value
        and then Value >= OpenCV.Float32_Value'First
        and then Value <= OpenCV.Float32_Value'Last;
   end Is_Finite_Public_Float32;

   --  Raises OpenCV_Error with Message unless every Box field is finite.
   procedure Validate_Finite_Rotated_Rect
     (Box : OpenCV.Rotated_Rect; Message : String)
   is
      pragma Suppress (Validity_Check);
   begin
      if not Is_Finite_Public_Float32 (Box.Center.X)
        or else not Is_Finite_Public_Float32 (Box.Center.Y)
        or else not Is_Finite_Public_Float32 (Box.Size.Width)
        or else not Is_Finite_Public_Float32 (Box.Size.Height)
        or else not Is_Finite_Public_Float32 (Box.Angle_Degrees)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, Message);
      end if;
   end Validate_Finite_Rotated_Rect;

   procedure Validate_Box (Box : OpenCV.Rotated_Rect) is
   begin
      Validate_Finite_Rotated_Rect
        (Box, "Box_Points requires finite rotated rectangle fields");
   end Validate_Box;

   function To_Public_Box_Vertices
     (Value : Internal.C_API.C_Box_Vertices) return Box_Vertices
   is
      pragma Suppress (Validity_Check);
   begin
      return
        (1 =>
           (X =>
              To_Public_Float32 (Value.V0_X, "box vertex 1 X is not finite"),
            Y =>
              To_Public_Float32 (Value.V0_Y, "box vertex 1 Y is not finite")),
         2 =>
           (X =>
              To_Public_Float32 (Value.V1_X, "box vertex 2 X is not finite"),
            Y =>
              To_Public_Float32 (Value.V1_Y, "box vertex 2 Y is not finite")),
         3 =>
           (X =>
              To_Public_Float32 (Value.V2_X, "box vertex 3 X is not finite"),
            Y =>
              To_Public_Float32 (Value.V2_Y, "box vertex 3 Y is not finite")),
         4 =>
           (X =>
              To_Public_Float32 (Value.V3_X, "box vertex 4 X is not finite"),
            Y =>
              To_Public_Float32 (Value.V3_Y, "box vertex 4 Y is not finite")));
   end To_Public_Box_Vertices;

   function Box_Points (Box : OpenCV.Rotated_Rect) return Box_Vertices is
      pragma Suppress (Validity_Check);
      Packed : aliased Internal.C_API.C_Rotated_Rect :=
        (Center_X      => Interfaces.C.C_float (Box.Center.X),
         Center_Y      => Interfaces.C.C_float (Box.Center.Y),
         Width         => Interfaces.C.C_float (Box.Size.Width),
         Height        => Interfaces.C.C_float (Box.Size.Height),
         Angle_Degrees => Interfaces.C.C_float (Box.Angle_Degrees));
      Result : aliased Internal.C_API.C_Box_Vertices :=
        (V0_X => 0.0,
         V0_Y => 0.0,
         V1_X => 0.0,
         V1_Y => 0.0,
         V2_X => 0.0,
         V2_Y => 0.0,
         V3_X => 0.0,
         V3_Y => 0.0);
      Status : Internal.C_API.Status;
   begin
      Validate_Box (Box);
      Status := Internal.C_API.Box_Points (Packed'Access, Result'Access);
      Raise_On_Error (Status, "Box_Points");
      return To_Public_Box_Vertices (Result);
   end Box_Points;

   function To_Public_Rotated_Rect
     (Value : Internal.C_API.C_Rotated_Rect) return OpenCV.Rotated_Rect
   is
      pragma Suppress (Validity_Check);
      use type OpenCV.Float32_Value;
      Center_X : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.Center_X, "rotated rectangle center X is not finite");
      Center_Y : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.Center_Y, "rotated rectangle center Y is not finite");
      Width    : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.Width, "rotated rectangle width is not finite");
      Height   : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.Height, "rotated rectangle height is not finite");
      Angle    : constant OpenCV.Float32_Value :=
        To_Public_Float32
          (Value.Angle_Degrees, "rotated rectangle angle is not finite");
   begin
      if Width < 0.0 or else Height < 0.0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "rotated rectangle size is negative");
      end if;
      return
        (Center        => (X => Center_X, Y => Center_Y),
         Size          => (Width => Width, Height => Height),
         Angle_Degrees => Angle);
   end To_Public_Rotated_Rect;

   function Minimum_Area_Rectangle
     (Points : Contour) return OpenCV.Rotated_Rect
   is
      pragma Suppress (Validity_Check);
      Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      Result : aliased Internal.C_API.C_Rotated_Rect :=
        (Center_X      => 0.0,
         Center_Y      => 0.0,
         Width         => 0.0,
         Height        => 0.0,
         Angle_Degrees => 0.0);
      Status : Internal.C_API.Status;
   begin
      if Packed'Length = 0 then
         Status := Internal.C_API.Min_Area_Rect (null, 0, Result'Access);
      else
         Status :=
           Internal.C_API.Min_Area_Rect
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              Result'Access);
      end if;
      Raise_On_Error (Status, "minimum area rectangle");
      return To_Public_Rotated_Rect (Result);
   end Minimum_Area_Rectangle;

   function Fit_Ellipse (Points : Contour) return OpenCV.Rotated_Rect is
      pragma Suppress (Validity_Check);
      Result : aliased Internal.C_API.C_Rotated_Rect :=
        (Center_X      => 0.0,
         Center_Y      => 0.0,
         Width         => 0.0,
         Height        => 0.0,
         Angle_Degrees => 0.0);
      Status : Internal.C_API.Status;
   begin
      if Points'Length < 5 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Fit_Ellipse requires at least five points");
      end if;

      --  OpenCV fitEllipseNoDirect allocates n*12+n doubles with signed
      --  int arithmetic. Reject that overflow before packing or the ABI.
      if Points'Length > Natural (Interfaces.Integer_32'Last) / 13 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Fit_Ellipse point count exceeds native allocation range");
      end if;

      declare
         Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      begin
         Status :=
           Internal.C_API.Fit_Ellipse
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              Result'Access);
      end;
      Raise_On_Error (Status, "fit ellipse");
      return To_Public_Rotated_Rect (Result);
   end Fit_Ellipse;

   type Ellipse_Fit_Variant is (AMS_Variant, Direct_Variant);

   --  Shared body of Fit_Ellipse_AMS and Fit_Ellipse_Direct. Both native
   --  algorithms need at least five points and can fall back to
   --  fitEllipseNoDirect, whose n*12+n signed int allocation bounds the
   --  count.
   function Fit_Ellipse_With
     (Points : Contour; Variant : Ellipse_Fit_Variant; Operation : String)
      return OpenCV.Rotated_Rect
   is
      pragma Suppress (Validity_Check);
      Result : aliased Internal.C_API.C_Rotated_Rect :=
        (Center_X      => 0.0,
         Center_Y      => 0.0,
         Width         => 0.0,
         Height        => 0.0,
         Angle_Degrees => 0.0);
      Status : Internal.C_API.Status;
   begin
      if Points'Length < 5 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires at least five points");
      end if;
      if Points'Length > Natural (Interfaces.Integer_32'Last) / 13 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " point count exceeds native allocation range");
      end if;

      declare
         Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      begin
         case Variant is
            when AMS_Variant    =>
               Status :=
                 Internal.C_API.Fit_Ellipse_AMS
                   (Packed (Packed'First)'Access,
                    Interfaces.Integer_32 (Packed'Length),
                    Result'Access);

            when Direct_Variant =>
               Status :=
                 Internal.C_API.Fit_Ellipse_Direct
                   (Packed (Packed'First)'Access,
                    Interfaces.Integer_32 (Packed'Length),
                    Result'Access);
         end case;
      end;
      Raise_On_Error
        (Status,
         (case Variant is
            when AMS_Variant    => "fit ellipse AMS",
            when Direct_Variant => "fit ellipse direct"));
      return To_Public_Rotated_Rect (Result);
   end Fit_Ellipse_With;

   function Fit_Ellipse_AMS (Points : Contour) return OpenCV.Rotated_Rect is
   begin
      return Fit_Ellipse_With (Points, AMS_Variant, "Fit_Ellipse_AMS");
   end Fit_Ellipse_AMS;

   function To_C_Line_Fit_Distance
     (Distance : Line_Fit_Distance) return Interfaces.Integer_32 is
   begin
      case Distance is
         when L2     =>
            return Internal.C_API.Line_Fit_L2;

         when L1     =>
            return Internal.C_API.Line_Fit_L1;

         when L12    =>
            return Internal.C_API.Line_Fit_L12;

         when Fair   =>
            return Internal.C_API.Line_Fit_Fair;

         when Welsch =>
            return Internal.C_API.Line_Fit_Welsch;

         when Huber  =>
            return Internal.C_API.Line_Fit_Huber;
      end case;
   end To_C_Line_Fit_Distance;

   --  Raises OpenCV_Error unless Value is finite, nonnegative, and at most
   --  Float32_Value'Last, the range OpenCV's binary32 narrowing accepts.
   procedure Validate_Line_Fit_Scalar
     (Value : OpenCV.Float64_Value; Name : String)
   is
      pragma Suppress (Validity_Check);
      use type OpenCV.Float64_Value;
   begin
      if not (Value = Value
              and then Value >= 0.0
              and then Value
                       <= OpenCV.Float64_Value (OpenCV.Float32_Value'Last))
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Fit_Line_2D requires "
            & Name
            & " to be finite, nonnegative, and at most Float32_Value'Last");
      end if;
   end Validate_Line_Fit_Scalar;

   function Fit_Line_2D
     (Points          : Contour;
      Distance        : Line_Fit_Distance := L2;
      Parameter       : OpenCV.Float64_Value := 0.0;
      Radius_Accuracy : OpenCV.Float64_Value := 0.01;
      Angle_Accuracy  : OpenCV.Float64_Value := 0.01) return Fitted_Line_2D
   is
      pragma Suppress (Validity_Check);
      Result : aliased Internal.C_API.C_Line_2D :=
        (Direction_X => 0.0,
         Direction_Y => 0.0,
         Point_X     => 0.0,
         Point_Y     => 0.0);
      Status : Internal.C_API.Status;
   begin
      if Points'Length = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Fit_Line_2D requires at least one point");
      end if;
      --  Native fitLine computes count*2 in signed int for every distance.
      if Points'Length > Natural (Interfaces.Integer_32'Last) / 2 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Fit_Line_2D point count exceeds native allocation range");
      end if;
      Validate_Line_Fit_Scalar (Parameter, "Parameter");
      Validate_Line_Fit_Scalar (Radius_Accuracy, "Radius_Accuracy");
      Validate_Line_Fit_Scalar (Angle_Accuracy, "Angle_Accuracy");

      declare
         Packed : Internal.C_API.Point_I32_Array := Pack_Contour (Points);
      begin
         Status :=
           Internal.C_API.Fit_Line_2D
             (Packed (Packed'First)'Access,
              Interfaces.Integer_32 (Packed'Length),
              To_C_Line_Fit_Distance (Distance),
              Interfaces.C.double (Parameter),
              Interfaces.C.double (Radius_Accuracy),
              Interfaces.C.double (Angle_Accuracy),
              Result'Access);
      end;
      Raise_On_Error (Status, "fit line 2D");
      return
        (Direction =>
           (X =>
              To_Public_Float32
                (Result.Direction_X, "fitted line direction X is not finite"),
            Y =>
              To_Public_Float32
                (Result.Direction_Y, "fitted line direction Y is not finite")),
         Point     =>
           (X =>
              To_Public_Float32
                (Result.Point_X, "fitted line point X is not finite"),
            Y =>
              To_Public_Float32
                (Result.Point_Y, "fitted line point Y is not finite")));
   end Fit_Line_2D;

   function Fit_Ellipse_Direct (Points : Contour) return OpenCV.Rotated_Rect is
   begin
      return Fit_Ellipse_With (Points, Direct_Variant, "Fit_Ellipse_Direct");
   end Fit_Ellipse_Direct;

   procedure Validate_Get_Rotation_Matrix_2D
     (Center : OpenCV.Float32_Point;
      Angle  : OpenCV.Float64_Value;
      Scale  : OpenCV.Float64_Value)
   is
      --  The arguments may be Inf/NaN; this procedure rejects them.
      pragma Suppress (Validity_Check);
      use type OpenCV.Float32_Value;
      use type OpenCV.Float64_Value;
   begin
      if Center.X /= Center.X
        or else Center.X > OpenCV.Float32_Value'Last
        or else Center.X < OpenCV.Float32_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Rotation_Matrix_2D requires a finite Center.X");
      end if;

      if Center.Y /= Center.Y
        or else Center.Y > OpenCV.Float32_Value'Last
        or else Center.Y < OpenCV.Float32_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Rotation_Matrix_2D requires a finite Center.Y");
      end if;

      if Angle /= Angle
        or else Angle > OpenCV.Float64_Value'Last
        or else Angle < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Rotation_Matrix_2D requires a finite Angle");
      end if;

      if Scale /= Scale
        or else Scale > OpenCV.Float64_Value'Last
        or else Scale < OpenCV.Float64_Value'First
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Get_Rotation_Matrix_2D requires a finite Scale");
      end if;
   end Validate_Get_Rotation_Matrix_2D;

   function Reduced_Degrees
     (Angle : OpenCV.Float64_Value; Units : OpenCV.Angle_Unit)
      return OpenCV.Float64_Value
   is
      use type OpenCV.Float64_Value;
      Full_Turn : OpenCV.Float64_Value;
      Reduced   : OpenCV.Float64_Value;
   begin
      if Units = OpenCV.Degrees then
         Full_Turn := 360.0;
         return OpenCV.Float64_Value'Remainder (Angle, Full_Turn);
      end if;

      Full_Turn :=
        OpenCV.Float64_Value (2.0) * OpenCV.Float64_Value (Ada.Numerics.Pi);
      Reduced := OpenCV.Float64_Value'Remainder (Angle, Full_Turn);
      return
        Reduced
        * (OpenCV.Float64_Value (180.0)
           / OpenCV.Float64_Value (Ada.Numerics.Pi));
   end Reduced_Degrees;

   function Get_Rotation_Matrix_2D
     (Center : OpenCV.Float32_Point;
      Angle  : OpenCV.Float64_Value;
      Scale  : OpenCV.Float64_Value := 1.0;
      Units  : OpenCV.Angle_Unit := OpenCV.Degrees) return OpenCV.Core.Mat
   is
      --  Passes possibly Inf/NaN arguments to their validation, and native
      --  coefficients that finite inputs can overflow to Inf/NaN to
      --  To_Public_Float64.
      pragma Suppress (Validity_Check);
      Degrees : OpenCV.Float64_Value;
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

   --  Converts the first Count native binary32 points of Output. Callers
   --  ensure Count <= Output'Length.
   function To_Public_Float32_Points
     (Output    : Internal.C_API.Point_F32_Array;
      Count     : Natural;
      Operation : String) return Float32_Point_Array
   is
      pragma Suppress (Validity_Check);
      Result : Float32_Point_Array (1 .. Count);
   begin
      for Position in Result'Range loop
         declare
            Native : Internal.C_API.Point_F32 renames
              Output (Output'First + Position - 1);
         begin
            Result (Position) :=
              (X =>
                 To_Public_Float32
                   (Native.X, Operation & " vertex X is not finite"),
               Y =>
                 To_Public_Float32
                   (Native.Y, Operation & " vertex Y is not finite"));
         end;
      end loop;
      return Result;
   end To_Public_Float32_Points;

   --  Public policy for Intersect_Convex_Polygons inputs: at least three
   --  binary32-exact vertices forming a simple, strictly convex polygon
   --  traversed once. isContourConvex alone is insufficient: it accepts
   --  self-intersecting stars and repeated traversals, which OpenCV 4.x
   --  before 4.11 can turn into an intersection buffer overflow.
   procedure Validate_Convex_Polygon (Polygon : Contour; Name : String) is
   begin
      if Polygon'Length < 3 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Intersect_Convex_Polygons requires "
            & Name
            & " to have at least three vertices");
      end if;
      if not Internal.Intersection.Is_Binary32_Exact (Polygon) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Intersect_Convex_Polygons requires "
            & Name
            & " coordinates in -2**24 .. 2**24");
      end if;

      declare
         Hull : constant Point_Index_Array := Convex_Hull_Indices (Polygon);
      begin
         if not Internal.Intersection.Is_Contour_Order_Hull
                  (Polygon'First, Polygon'Last, Hull)
         then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Intersect_Convex_Polygons requires "
               & Name
               & " to be a simple strictly convex polygon: every vertex "
               & "must be a convex hull vertex, visited in hull order");
         end if;
      end;
   end Validate_Convex_Polygon;

   --  Public policy shared by both Intersect_Convex_Polygons overloads, for
   --  integer polygons that each passed Validate_Convex_Polygon: OpenCV 4.x
   --  before 4.11 stays within its result buffer only while its tests are
   --  exact, which needs every binary32 coordinate difference to be exact.
   --  Rule states the span limit in the caller's units for the diagnostic.
   procedure Validate_Exact_Spans
     (Left, Right : Contour;
      Rule        : String :=
        "at most 2**24, or 2**25 when every coordinate is even") is
   begin
      if not Internal.Intersection.Has_Exact_Differences
               (Left,
                Right,
                Internal.Convexity.Bounds_Of (Left),
                Internal.Convexity.Bounds_Of (Right))
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Intersect_Convex_Polygons requires the X and Y spans of Left "
            & "and Right together to be "
            & Rule);
      end if;
   end Validate_Exact_Spans;

   procedure Validate_Intersection_Counts (Left_Length, Right_Length : Natural)
   is
   begin
      if not Internal.Intersection.Is_Safe_Input_Count
               (Left_Length, Right_Length)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Intersect_Convex_Polygons point counts exceed the native "
            & "allocation range");
      end if;
   end Validate_Intersection_Counts;

   --  The public result of a native intersection that wrote Count vertices
   --  to Output and the area Area.
   function To_Public_Intersection
     (Output : Internal.C_API.Point_F32_Array;
      Count  : Interfaces.Integer_32;
      Area   : Interfaces.C.C_float) return Convex_Polygon_Intersection
   is
      --  To_Public_Float32 inspects the raw native area and vertices.
      pragma Suppress (Validity_Check);
      use type Interfaces.Integer_32;
      use type OpenCV.Float32_Value;
      Public_Area : OpenCV.Float32_Value;
   begin
      if Count < 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Intersect_Convex_Polygons failed: negative vertex count");
      end if;
      if Natural (Count) > Output'Length then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Intersect_Convex_Polygons failed: vertex count exceeds "
            & "capacity");
      end if;
      Public_Area :=
        To_Public_Float32
          (Area, "Intersect_Convex_Polygons area is not finite");
      if Public_Area < 0.0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Intersect_Convex_Polygons failed: OpenCV reported that the "
            & "intersection did not converge");
      end if;
      return
        (Vertex_Count => Natural (Count),
         Area         => Public_Area,
         Vertices     =>
           To_Public_Float32_Points
             (Output, Natural (Count), "Intersect_Convex_Polygons"));
   end To_Public_Intersection;

   function Intersect_Convex_Polygons
     (Left, Right : Contour; Handle_Nested : Boolean := True)
      return Convex_Polygon_Intersection is
   begin
      Validate_Convex_Polygon (Left, "Left");
      Validate_Convex_Polygon (Right, "Right");
      Validate_Exact_Spans (Left, Right);
      Validate_Intersection_Counts (Left'Length, Right'Length);

      declare
         pragma Suppress (Validity_Check);
         Packed_Left  : Internal.C_API.Point_I32_Array := Pack_Contour (Left);
         Packed_Right : Internal.C_API.Point_I32_Array := Pack_Contour (Right);
         --  At most Left'Length + Right'Length intersection vertices.
         Capacity     : constant Natural :=
           Internal.Intersection.Output_Capacity (Left'Length, Right'Length);
         Output       : Internal.C_API.Point_F32_Array (0 .. Capacity - 1);
         Count        : aliased Interfaces.Integer_32 := 0;
         Area         : aliased Interfaces.C.C_float := 0.0;
         Status       : Internal.C_API.Status;
      begin
         Status :=
           Internal.C_API.Intersect_Convex_Convex
             (Packed_Left (Packed_Left'First)'Access,
              Interfaces.Integer_32 (Packed_Left'Length),
              Packed_Right (Packed_Right'First)'Access,
              Interfaces.Integer_32 (Packed_Right'Length),
              To_C_Boolean (Handle_Nested),
              Output (Output'First)'Access,
              Interfaces.Integer_32 (Output'Length),
              Count'Access,
              Area'Access);
         Raise_On_Error (Status, "Intersect_Convex_Polygons");
         return To_Public_Intersection (Output, Count, Area);
      end;
   end Intersect_Convex_Polygons;

   function To_C_Rotated_Rect
     (Box : OpenCV.Rotated_Rect) return Internal.C_API.C_Rotated_Rect is
   begin
      return
        (Center_X      => Interfaces.C.C_float (Box.Center.X),
         Center_Y      => Interfaces.C.C_float (Box.Center.Y),
         Width         => Interfaces.C.C_float (Box.Size.Width),
         Height        => Interfaces.C.C_float (Box.Size.Height),
         Angle_Degrees => Interfaces.C.C_float (Box.Angle_Degrees));
   end To_C_Rotated_Rect;

   function To_Public_Intersection_Kind
     (Kind : Interfaces.Integer_32) return Rectangle_Intersection_Kind
   is
      use type Interfaces.Integer_32;
   begin
      if Kind = Internal.C_API.Rectangles_Intersect_None then
         return No_Intersection;
      elsif Kind = Internal.C_API.Rectangles_Intersect_Partial then
         return Partial_Intersection;
      elsif Kind = Internal.C_API.Rectangles_Intersect_Full then
         return Full_Intersection;
      else
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Intersect_Rotated_Rectangles failed: invalid kind encoding");
      end if;
   end To_Public_Intersection_Kind;

   function Intersect_Rotated_Rectangles
     (Left, Right : OpenCV.Rotated_Rect) return Rotated_Rectangle_Intersection
   is
      pragma Suppress (Validity_Check);
      use type Interfaces.Integer_32;
   begin
      Validate_Finite_Rotated_Rect
        (Left, "Intersect_Rotated_Rectangles requires finite Left fields");
      Validate_Finite_Rotated_Rect
        (Right, "Intersect_Rotated_Rectangles requires finite Right fields");

      declare
         Packed_Left  : aliased constant Internal.C_API.C_Rotated_Rect :=
           To_C_Rotated_Rect (Left);
         Packed_Right : aliased constant Internal.C_API.C_Rotated_Rect :=
           To_C_Rotated_Rect (Right);
         --  OpenCV reduces the region to at most eight vertices.
         Output       :
           Internal.C_API.Point_F32_Array
             (0 .. Rectangle_Intersection_Vertex_Count'Last - 1);
         Kind         : aliased Interfaces.Integer_32 := 0;
         Count        : aliased Interfaces.Integer_32 := 0;
         Status       : Internal.C_API.Status;
      begin
         Status :=
           Internal.C_API.Rotated_Rectangle_Intersection
             (Packed_Left'Access,
              Packed_Right'Access,
              Kind'Access,
              Output (Output'First)'Access,
              Interfaces.Integer_32 (Output'Length),
              Count'Access);
         Raise_On_Error (Status, "Intersect_Rotated_Rectangles");
         if Count < 0 then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Intersect_Rotated_Rectangles failed: negative vertex count");
         end if;
         if Natural (Count) > Output'Length then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Intersect_Rotated_Rectangles failed: vertex count exceeds "
               & "capacity");
         end if;
         return
           (Vertex_Count => Natural (Count),
            Kind         => To_Public_Intersection_Kind (Kind),
            Vertices     =>
              To_Public_Float32_Points
                (Output, Natural (Count), "Intersect_Rotated_Rectangles"));
      end;
   end Intersect_Rotated_Rectangles;

   function Is_Finite_Public_Float64
     (Value : OpenCV.Float64_Value) return Boolean
   is
      pragma Suppress (Validity_Check);
      use type OpenCV.Float64_Value;
   begin
      return
        Value = Value
        and then Value >= OpenCV.Float64_Value'First
        and then Value <= OpenCV.Float64_Value'Last;
   end Is_Finite_Public_Float64;

   --  Raises OpenCV_Error with Count_Message unless Points has exactly Count
   --  points, and with Finite_Message unless every coordinate is finite.
   procedure Validate_Correspondence
     (Points         : Float32_Point_Array;
      Count          : Positive;
      Count_Message  : String;
      Finite_Message : String)
   is
      pragma Suppress (Validity_Check);
   begin
      if Points'Length /= Count then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, Count_Message);
      end if;

      for Point of Points loop
         if not Is_Finite_Public_Float32 (Point.X)
           or else not Is_Finite_Public_Float32 (Point.Y)
         then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity, Finite_Message);
         end if;
      end loop;
   end Validate_Correspondence;

   function To_C_Point_F32
     (Point : OpenCV.Float32_Point) return Internal.C_API.Point_F32 is
   begin
      return
        (X => Interfaces.C.C_float (Point.X),
         Y => Interfaces.C.C_float (Point.Y));
   end To_C_Point_F32;

   --  Callers ensure Points'Length = 3.
   function To_C_Triangle_Points
     (Points : Float32_Point_Array) return Internal.C_API.C_Triangle_Points
   is
      Result : Internal.C_API.C_Triangle_Points :=
        (Points => (others => (X => 0.0, Y => 0.0)));
   begin
      for Offset in Result.Points'Range loop
         Result.Points (Offset) :=
           To_C_Point_F32 (Points (Points'First + Offset));
      end loop;
      return Result;
   end To_C_Triangle_Points;

   --  Callers ensure Points'Length = 4.
   function To_C_Quad_Points
     (Points : Float32_Point_Array) return Internal.C_API.C_Quad_Points
   is
      Result : Internal.C_API.C_Quad_Points :=
        (Points => (others => (X => 0.0, Y => 0.0)));
   begin
      for Offset in Result.Points'Range loop
         Result.Points (Offset) :=
           To_C_Point_F32 (Points (Points'First + Offset));
      end loop;
      return Result;
   end To_C_Quad_Points;

   function To_C_Affine
     (Transform : Affine_Transform_2D) return Internal.C_API.C_Affine_2x3_F64
   is
   begin
      return
        (M00 => Interfaces.C.double (Transform (1, 1)),
         M01 => Interfaces.C.double (Transform (1, 2)),
         M02 => Interfaces.C.double (Transform (1, 3)),
         M10 => Interfaces.C.double (Transform (2, 1)),
         M11 => Interfaces.C.double (Transform (2, 2)),
         M12 => Interfaces.C.double (Transform (2, 3)));
   end To_C_Affine;

   function To_Public_Affine
     (Value : Internal.C_API.C_Affine_2x3_F64; Operation : String)
      return Affine_Transform_2D
   is
      --  Pass possibly non-finite native doubles to To_Public_Float64, which
      --  raises OpenCV_Error, without an Ada validity failure.
      pragma Suppress (Validity_Check);
      Message : constant String :=
        Operation & " failed: OpenCV returned a non-finite coefficient";
   begin
      return
        ((To_Public_Float64 (Value.M00, Message),
          To_Public_Float64 (Value.M01, Message),
          To_Public_Float64 (Value.M02, Message)),
         (To_Public_Float64 (Value.M10, Message),
          To_Public_Float64 (Value.M11, Message),
          To_Public_Float64 (Value.M12, Message)));
   end To_Public_Affine;

   function To_Public_Perspective
     (Value : Internal.C_API.C_Perspective_3x3_F64)
      return Perspective_Transform_2D
   is
      --  Pass possibly non-finite native doubles to To_Public_Float64, which
      --  raises OpenCV_Error, without an Ada validity failure.
      pragma Suppress (Validity_Check);
      Message : constant String :=
        "Get_Perspective_Transform failed: OpenCV returned a non-finite "
        & "coefficient";
   begin
      return
        ((To_Public_Float64 (Value.M00, Message),
          To_Public_Float64 (Value.M01, Message),
          To_Public_Float64 (Value.M02, Message)),
         (To_Public_Float64 (Value.M10, Message),
          To_Public_Float64 (Value.M11, Message),
          To_Public_Float64 (Value.M12, Message)),
         (To_Public_Float64 (Value.M20, Message),
          To_Public_Float64 (Value.M21, Message),
          To_Public_Float64 (Value.M22, Message)));
   end To_Public_Perspective;

   function Get_Affine_Transform
     (Source, Destination : Float32_Point_Array) return Affine_Transform_2D is
   begin
      Validate_Correspondence
        (Source,
         3,
         "Get_Affine_Transform requires exactly three Source points",
         "Get_Affine_Transform requires finite Source coordinates");
      Validate_Correspondence
        (Destination,
         3,
         "Get_Affine_Transform requires exactly three Destination points",
         "Get_Affine_Transform requires finite Destination coordinates");

      declare
         Packed_Source      :
           aliased constant Internal.C_API.C_Triangle_Points :=
             To_C_Triangle_Points (Source);
         Packed_Destination :
           aliased constant Internal.C_API.C_Triangle_Points :=
             To_C_Triangle_Points (Destination);
         Result             : aliased Internal.C_API.C_Affine_2x3_F64 :=
           (others => 0.0);
         Status             : Internal.C_API.Status;
      begin
         Status :=
           Internal.C_API.Get_Affine_Transform
             (Packed_Source'Access, Packed_Destination'Access, Result'Access);
         Raise_On_Error (Status, "Get_Affine_Transform");
         return To_Public_Affine (Result, "Get_Affine_Transform");
      end;
   end Get_Affine_Transform;

   function Invert_Affine_Transform
     (Transform : Affine_Transform_2D) return Affine_Transform_2D
   is
      --  Inspect possibly non-finite coefficients without an Ada validity
      --  failure, so they raise OpenCV_Error.
      pragma Suppress (Validity_Check);
   begin
      for Coefficient of Transform loop
         if not Is_Finite_Public_Float64 (Coefficient) then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Invert_Affine_Transform requires finite coefficients");
         end if;
      end loop;

      declare
         Packed : aliased constant Internal.C_API.C_Affine_2x3_F64 :=
           To_C_Affine (Transform);
         Result : aliased Internal.C_API.C_Affine_2x3_F64 := (others => 0.0);
         Status : Internal.C_API.Status;
      begin
         Status :=
           Internal.C_API.Invert_Affine_Transform
             (Packed'Access, Result'Access);
         Raise_On_Error (Status, "Invert_Affine_Transform");
         return To_Public_Affine (Result, "Invert_Affine_Transform");
      end;
   end Invert_Affine_Transform;

   function To_C_Perspective_Solve_Method
     (Method : Perspective_Solve_Method) return Interfaces.Integer_32 is
   begin
      case Method is
         when LU_Decomposition             =>
            return Internal.C_API.Perspective_Solve_LU;

         when Singular_Value_Decomposition =>
            return Internal.C_API.Perspective_Solve_SVD;

         when QR_Decomposition             =>
            return Internal.C_API.Perspective_Solve_QR;
      end case;
   end To_C_Perspective_Solve_Method;

   function Get_Perspective_Transform
     (Source, Destination : Float32_Point_Array;
      Method              : Perspective_Solve_Method := LU_Decomposition)
      return Perspective_Transform_2D is
   begin
      Validate_Correspondence
        (Source,
         4,
         "Get_Perspective_Transform requires exactly four Source points",
         "Get_Perspective_Transform requires finite Source coordinates");
      Validate_Correspondence
        (Destination,
         4,
         "Get_Perspective_Transform requires exactly four Destination points",
         "Get_Perspective_Transform requires finite Destination coordinates");

      declare
         Packed_Source      : aliased constant Internal.C_API.C_Quad_Points :=
           To_C_Quad_Points (Source);
         Packed_Destination : aliased constant Internal.C_API.C_Quad_Points :=
           To_C_Quad_Points (Destination);
         Result             : aliased Internal.C_API.C_Perspective_3x3_F64 :=
           (others => 0.0);
         Status             : Internal.C_API.Status;
      begin
         Status :=
           Internal.C_API.Get_Perspective_Transform
             (Packed_Source'Access,
              Packed_Destination'Access,
              To_C_Perspective_Solve_Method (Method),
              Result'Access);
         Raise_On_Error (Status, "Get_Perspective_Transform");
         return To_Public_Perspective (Result);
      end;
   end Get_Perspective_Transform;

   type Float64_Value_List is
     array (Positive range <>) of OpenCV.Float64_Value;

   --  Raises OpenCV_Error unless Point is finite and every coefficient is
   --  finite and within Internal.Transforms.Coefficient_Limit.
   procedure Validate_Transform_Point_Input
     (Point : OpenCV.Float32_Point; Coefficients : Float64_Value_List)
   is
      pragma Suppress (Validity_Check);
   begin
      if not Is_Finite_Public_Float32 (Point.X)
        or else not Is_Finite_Public_Float32 (Point.Y)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Transform_Point requires a finite Point");
      end if;

      for Coefficient of Coefficients loop
         if not Is_Finite_Public_Float64 (Coefficient)
           or else not Internal.Transforms.Is_Bounded_Coefficient (Coefficient)
         then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Transform_Point requires finite coefficients of magnitude "
               & "at most 1.0E+269");
         end if;
      end loop;
   end Validate_Transform_Point_Input;

   function Transform_Point
     (Transform : Affine_Transform_2D; Point : OpenCV.Float32_Point)
      return OpenCV.Float32_Point
   is
      --  Validate possibly non-finite inputs without an Ada validity failure.
      pragma Suppress (Validity_Check);
      package Transforms renames Internal.Transforms;
   begin
      Validate_Transform_Point_Input
        (Point,
         (Transform (1, 1),
          Transform (1, 2),
          Transform (1, 3),
          Transform (2, 1),
          Transform (2, 2),
          Transform (2, 3)));

      declare
         X        : constant OpenCV.Float64_Value :=
           OpenCV.Float64_Value (Point.X);
         Y        : constant OpenCV.Float64_Value :=
           OpenCV.Float64_Value (Point.Y);
         Mapped_X : constant OpenCV.Float64_Value :=
           Transforms.Linear_Form
             (Transform (1, 1), Transform (1, 2), Transform (1, 3), X, Y);
         Mapped_Y : constant OpenCV.Float64_Value :=
           Transforms.Linear_Form
             (Transform (2, 1), Transform (2, 2), Transform (2, 3), X, Y);
      begin
         if not Transforms.Is_Binary32_Coordinate (Mapped_X)
           or else not Transforms.Is_Binary32_Coordinate (Mapped_Y)
         then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Transform_Point result is outside binary32 range");
         end if;
         return
           (X => Transforms.To_Binary32 (Mapped_X),
            Y => Transforms.To_Binary32 (Mapped_Y));
      end;
   end Transform_Point;

   function Transform_Point
     (Transform : Perspective_Transform_2D; Point : OpenCV.Float32_Point)
      return OpenCV.Float32_Point
   is
      --  Validate possibly non-finite inputs without an Ada validity failure.
      pragma Suppress (Validity_Check);
      package Transforms renames Internal.Transforms;
      use type OpenCV.Float64_Value;
   begin
      Validate_Transform_Point_Input
        (Point,
         (Transform (1, 1),
          Transform (1, 2),
          Transform (1, 3),
          Transform (2, 1),
          Transform (2, 2),
          Transform (2, 3),
          Transform (3, 1),
          Transform (3, 2),
          Transform (3, 3)));

      declare
         X        : constant OpenCV.Float64_Value :=
           OpenCV.Float64_Value (Point.X);
         Y        : constant OpenCV.Float64_Value :=
           OpenCV.Float64_Value (Point.Y);
         U        : constant OpenCV.Float64_Value :=
           Transforms.Linear_Form
             (Transform (1, 1), Transform (1, 2), Transform (1, 3), X, Y);
         V        : constant OpenCV.Float64_Value :=
           Transforms.Linear_Form
             (Transform (2, 1), Transform (2, 2), Transform (2, 3), X, Y);
         W        : constant OpenCV.Float64_Value :=
           Transforms.Linear_Form
             (Transform (3, 1), Transform (3, 2), Transform (3, 3), X, Y);
         Mapped_X : OpenCV.Float64_Value;
         Mapped_Y : OpenCV.Float64_Value;
         Fits_X   : Boolean;
         Fits_Y   : Boolean;
      begin
         if W = 0.0 then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Transform_Point maps Point to infinity (W = 0)");
         end if;
         Transforms.Divide (U, W, Mapped_X, Fits_X);
         Transforms.Divide (V, W, Mapped_Y, Fits_Y);
         if not Fits_X or else not Fits_Y then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               "Transform_Point result is outside binary32 range");
         end if;
         return
           (X => Transforms.To_Binary32 (Mapped_X),
            Y => Transforms.To_Binary32 (Mapped_Y));
      end;
   end Transform_Point;

   --  Float32 point sets. Every overload rejects non-finite coordinates
   --  before packing, so packed points are finite.

   package Float32_Points renames Internal.Float32_Points;

   --  Raises OpenCV_Error unless every coordinate of Points is finite.
   procedure Validate_Finite_Points
     (Points : Float32_Point_Array; Operation : String)
   is
      --  Points may hold NaN or infinities; inspect them without an Ada
      --  validity failure.
      pragma Suppress (Validity_Check);
   begin
      for Point of Points loop
         if not Is_Finite_Public_Float32 (Point.X)
           or else not Is_Finite_Public_Float32 (Point.Y)
         then
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               Operation & " requires finite point coordinates");
         end if;
      end loop;
   end Validate_Finite_Points;

   --  Packs Points in iteration order into a zero-based C ABI buffer, which
   --  is empty for empty Points. Positive_Zeros passes each -0.0
   --  coordinate as +0.0, for native convexHull, which compares its extreme
   --  points bitwise.
   function Pack_Float32_Points
     (Points : Float32_Point_Array; Positive_Zeros : Boolean := False)
      return Internal.C_API.Point_F32_Array
   is
      use type OpenCV.Float32_Value;

      function Packed
        (Value : OpenCV.Float32_Value) return Interfaces.C.C_float
      is (if Positive_Zeros and then Value = 0.0
          then 0.0
          else Interfaces.C.C_float (Value));
   begin
      if Points'Length > Natural (Interfaces.Integer_32'Last) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity, "point count exceeds C ABI range");
      end if;

      declare
         Result : Internal.C_API.Point_F32_Array (0 .. Points'Length - 1);
      begin
         for Offset in Result'Range loop
            Result (Offset) :=
              (X => Packed (Points (Points'First + Offset).X),
               Y => Packed (Points (Points'First + Offset).Y));
         end loop;
         return Result;
      end;
   end Pack_Float32_Points;

   --  The C ABI view of a point buffer: its first point, or null when it is
   --  empty, and its count.
   function First_Point
     (Packed : aliased Internal.C_API.Point_F32_Array)
      return access constant Internal.C_API.Point_F32
   is (if Packed'Length = 0 then null else Packed (Packed'First)'Access);

   function First_Output
     (Buffer : aliased in out Internal.C_API.Point_F32_Array)
      return access Internal.C_API.Point_F32
   is (if Buffer'Length = 0 then null else Buffer (Buffer'First)'Access);

   function Point_Count
     (Packed : Internal.C_API.Point_F32_Array) return Interfaces.Integer_32
   is (Interfaces.Integer_32 (Packed'Length));

   --  A zero-filled, zero-based C ABI output buffer of Capacity points.
   --  Declared from this result, a buffer has the unconstrained nominal
   --  subtype that First_Output's aliased parameter requires.
   function Output_Buffer
     (Capacity : Natural) return Internal.C_API.Point_F32_Array
   is (Internal.C_API.Point_F32_Array'
         (0 .. Capacity - 1 => (X => 0.0, Y => 0.0)));

   --  A native result count, checked against the capacity the caller gave.
   function Checked_Count
     (Count : Interfaces.Integer_32; Capacity : Natural; Operation : String)
      return Natural
   is
      use type Interfaces.Integer_32;
   begin
      if Count < 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " failed: negative result count");
      end if;
      if Natural (Count) > Capacity then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " failed: result count exceeds capacity");
      end if;
      return Natural (Count);
   end Checked_Count;

   --  The first Count native points of Output as a zero-based Float32 point
   --  set, or the null range 1 .. 0. Callers ensure Count <= Output'Length.
   function Unpack_Float32_Points
     (Output    : Internal.C_API.Point_F32_Array;
      Count     : Natural;
      Operation : String) return Float32_Point_Array
   is
      --  To_Public_Float32 inspects each raw native coordinate.
      pragma Suppress (Validity_Check);
   begin
      if Count = 0 then
         declare
            Empty : Float32_Point_Array (1 .. 0);
         begin
            return Empty;
         end;
      end if;

      declare
         Result : Float32_Point_Array (0 .. Count - 1);
      begin
         for Offset in Result'Range loop
            Result (Offset) :=
              (X =>
                 To_Public_Float32
                   (Output (Output'First + Offset).X,
                    Operation & " point X is not finite"),
               Y =>
                 To_Public_Float32
                   (Output (Output'First + Offset).Y,
                    Operation & " point Y is not finite"));
         end loop;
         return Result;
      end;
   end Unpack_Float32_Points;

   --  Raises OpenCV_Error when Points has more than Limit points, the
   --  largest count whose native signed 32-bit size arithmetic is defined.
   procedure Validate_Native_Count
     (Points : Float32_Point_Array; Limit : Natural; Operation : String) is
   begin
      if Points'Length > Limit then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " point count exceeds native allocation range");
      end if;
   end Validate_Native_Count;

   function To_Public_Boolean
     (Value : Interfaces.Integer_32; Operation : String) return Boolean is
   begin
      case Value is
         when 0      =>
            return False;

         when 1      =>
            return True;

         when others =>
            Ada.Exceptions.Raise_Exception
              (OpenCV.OpenCV_Error'Identity,
               Operation & " failed: invalid Boolean encoding");
      end case;
   end To_Public_Boolean;

   function Contour_Area
     (Points : Float32_Point_Array; Oriented : Boolean := False)
      return OpenCV.Float64_Value
   is
      --  To_Public_Float64 inspects the raw native result.
      pragma Suppress (Validity_Check);
      Area   : aliased Interfaces.C.double := 0.0;
      Status : Internal.C_API.Status;
   begin
      Validate_Finite_Points (Points, "Contour_Area");
      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
      begin
         Status :=
           Internal.C_API.Contour_Area_F32
             (First_Point (Packed),
              Point_Count (Packed),
              To_C_Boolean (Oriented),
              Area'Access);
      end;
      Raise_On_Error (Status, "contour area");
      return To_Public_Float64 (Area, "Contour_Area result is not finite");
   end Contour_Area;

   function Arc_Length
     (Points : Float32_Point_Array; Closed : Boolean)
      return OpenCV.Float64_Value
   is
      --  The native length overflows to infinity for very long segments;
      --  To_Public_Float64 inspects it.
      pragma Suppress (Validity_Check);
      Length : aliased Interfaces.C.double := 0.0;
      Status : Internal.C_API.Status;
   begin
      Validate_Finite_Points (Points, "Arc_Length");
      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
      begin
         Status :=
           Internal.C_API.Arc_Length_F32
             (First_Point (Packed),
              Point_Count (Packed),
              To_C_Boolean (Closed),
              Length'Access);
      end;
      Raise_On_Error (Status, "arc length");
      return
        To_Public_Float64
          (Length,
           "Arc_Length result is not finite: a segment overflows binary32");
   end Arc_Length;

   function Compute_Moments
     (Points : Float32_Point_Array) return Moments_Result
   is
      --  Native moments may be Inf/NaN; All_Finite inspects them before
      --  they are converted.
      pragma Suppress (Validity_Check);
      Result : aliased Internal.C_API.C_Moments;
      Status : Internal.C_API.Status;
   begin
      Validate_Finite_Points (Points, "Compute_Moments");
      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
      begin
         Status :=
           Internal.C_API.Contour_Moments_F32
             (First_Point (Packed), Point_Count (Packed), Result'Access);
      end;
      Raise_On_Error (Status, "contour moments");
      if not All_Finite (Result) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Compute_Moments result is not finite");
      end if;
      return To_Public_Moments (Result);
   end Compute_Moments;

   --  Public policy for Float32 Bounding_Rect: OpenCV floors the extreme
   --  coordinates to signed 32-bit integers and forms inclusive extents in
   --  signed 32-bit arithmetic.
   procedure Validate_Bounding_Extent
     (Bounds : Float32_Points.Coordinate_Bounds)
   is
      Limit : constant Long_Long_Integer :=
        Long_Long_Integer (Interfaces.Integer_32'Last);
   begin
      if not (Float32_Points.Is_Int32_Convertible (Bounds.Min_X)
              and then Float32_Points.Is_Int32_Convertible (Bounds.Max_X)
              and then Float32_Points.Is_Int32_Convertible (Bounds.Min_Y)
              and then Float32_Points.Is_Int32_Convertible (Bounds.Max_Y))
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Bounding_Rect requires coordinates of at least -2.0**31 and "
            & "less than 2.0**31");
      end if;
      if Float32_Points.Inclusive_Extent (Bounds.Min_X, Bounds.Max_X) > Limit
        or else Float32_Points.Inclusive_Extent (Bounds.Min_Y, Bounds.Max_Y)
                > Limit
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "bounding rect cannot be represented as OpenCV.Rect");
      end if;
   end Validate_Bounding_Extent;

   function Bounding_Rect (Points : Float32_Point_Array) return OpenCV.Rect is
      Result : aliased Internal.C_API.Rect_I32 :=
        (X => 0, Y => 0, Width => 0, Height => 0);
      Status : Internal.C_API.Status;
   begin
      Validate_Finite_Points (Points, "Bounding_Rect");
      if Points'Length > 0 then
         Validate_Bounding_Extent (Float32_Points.Bounds_Of (Points));
      end if;
      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
      begin
         Status :=
           Internal.C_API.Bounding_Rect_F32
             (First_Point (Packed), Point_Count (Packed), Result'Access);
      end;
      Raise_On_Error (Status, "bounding rect");
      return To_Public_Rect (Result);
   end Bounding_Rect;

   --  Raises OpenCV_Error unless no binary32 difference of two coordinates
   --  of Points overflows.
   procedure Validate_Binary32_Spans
     (Points : Float32_Point_Array; Operation : String) is
   begin
      if Points'Length > 0
        and then not Float32_Points.Spans_Are_Binary32
                       (Float32_Points.Bounds_Of (Points))
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation
            & " requires X and Y spans of at most Float32_Value'Last");
      end if;
   end Validate_Binary32_Spans;

   function Is_Convex (Points : Float32_Point_Array) return Boolean is
      Result : aliased Interfaces.Integer_32 := 0;
      Status : Internal.C_API.Status;
   begin
      Validate_Finite_Points (Points, "Is_Convex");
      --  OpenCV forms binary32 coordinate differences and binary32
      --  products of an X and a Y difference.
      Validate_Binary32_Spans (Points, "Is_Convex");
      if Points'Length > 0
        and then not Float32_Points.Span_Product_Is_Binary32
                       (Float32_Points.Bounds_Of (Points))
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Is_Convex requires the product of the X and Y spans to be at "
            & "most Float32_Value'Last / 2");
      end if;
      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
      begin
         Status :=
           Internal.C_API.Is_Convex_F32
             (First_Point (Packed), Point_Count (Packed), Result'Access);
      end;
      Raise_On_Error (Status, "is convex");
      return To_Public_Boolean (Result, "is convex");
   end Is_Convex;

   --  Raises OpenCV_Error unless the moments and Hu moments of Points are
   --  finite. OpenCV's matching silently skips non-finite Hu moments, so a
   --  finite score alone does not show that they were finite.
   procedure Validate_Shape_Moments
     (Points : Float32_Point_Array; Name : String) is
   begin
      declare
         Unused : constant Hu_Moments_Result :=
           Hu_Moments (Compute_Moments (Points));
         pragma Unreferenced (Unused);
      begin
         null;
      end;
   exception
      when OpenCV.OpenCV_Error =>
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Match_Shapes requires finite moments and Hu moments of " & Name);
   end Validate_Shape_Moments;

   function Match_Shapes
     (Left, Right : Float32_Point_Array; Method : Shape_Match_Method)
      return OpenCV.Float64_Value
   is
      --  Native scores may be Inf/NaN; To_Public_Float64 inspects them.
      pragma Suppress (Validity_Check);
      Score  : aliased Interfaces.C.double := 0.0;
      Status : Internal.C_API.Status;
   begin
      Validate_Finite_Points (Left, "Match_Shapes");
      Validate_Finite_Points (Right, "Match_Shapes");
      Validate_Shape_Moments (Left, "Left");
      Validate_Shape_Moments (Right, "Right");
      declare
         Packed_Left  : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Left);
         Packed_Right : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Right);
      begin
         Status :=
           Internal.C_API.Match_Shapes_F32
             (First_Point (Packed_Left),
              Point_Count (Packed_Left),
              First_Point (Packed_Right),
              Point_Count (Packed_Right),
              To_C_Match_Method (Method),
              Score'Access);
      end;
      Raise_On_Error (Status, "match shapes");
      return To_Public_Float64 (Score, "Match_Shapes result is not finite");
   end Match_Shapes;

   --  Validates a query of a Float32 polygon and calls native
   --  pointPolygonTest in the Measure_Distance mode.
   function Call_Point_Polygon_Test
     (Points           : Float32_Point_Array;
      Query            : OpenCV.Float32_Point;
      Measure_Distance : Interfaces.Integer_32;
      Operation        : String) return Interfaces.C.double
   is
      --  Query may be Inf/NaN, and the native result is inspected by the
      --  callers.
      pragma Suppress (Validity_Check);
      Result : aliased Interfaces.C.double := 0.0;
      Status : Internal.C_API.Status;
   begin
      Validate_Finite_Points (Points, Operation);
      --  OpenCV forms binary32 differences of contour coordinates. A
      --  difference between Query, within the cvRound range, and a contour
      --  coordinate cannot overflow.
      Validate_Binary32_Spans (Points, Operation);
      if not Is_Finite_Public_Float32 (Query.X)
        or else not Is_Finite_Public_Float32 (Query.Y)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires a finite Query");
      end if;
      if Points'Length > 0
        and then not (Float32_Points.Is_Int32_Convertible (Query.X)
                      and then Float32_Points.Is_Int32_Convertible (Query.Y))
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation
            & " requires Query coordinates of at least -2.0**31 and less "
            & "than 2.0**31");
      end if;

      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
      begin
         Status :=
           Internal.C_API.Point_Polygon_Test_F32
             (First_Point (Packed),
              Point_Count (Packed),
              Interfaces.C.C_float (Query.X),
              Interfaces.C.C_float (Query.Y),
              Measure_Distance,
              Result'Access);
      end;
      Raise_On_Error (Status, "point polygon test");
      return Result;
   end Call_Point_Polygon_Test;

   function Locate_Point
     (Points : Float32_Point_Array; Query : OpenCV.Float32_Point)
      return Contour_Point_Location
   is
      pragma Suppress (Validity_Check);
      use type Interfaces.C.double;
      Result : constant Interfaces.C.double :=
        Call_Point_Polygon_Test
          (Points,
           Query,
           Internal.C_API.Point_Polygon_Classify,
           "Locate_Point");
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

   --  Binary64 Sqrt (FLT_MAX): native pointPolygonTest starts its
   --  nearest-edge search at squared distance FLT_MAX, so it reports this
   --  magnitude, and never a larger one, when no edge is nearer.
   Distance_Search_Limit : constant OpenCV.Float64_Value :=
     1.844674352395373E+19;

   function Signed_Distance_To_Contour
     (Points : Float32_Point_Array; Query : OpenCV.Float32_Point)
      return OpenCV.Float64_Value
   is
      pragma Suppress (Validity_Check);
      use type OpenCV.Float64_Value;
      Distance : constant OpenCV.Float64_Value :=
        To_Public_Float64
          (Call_Point_Polygon_Test
             (Points,
              Query,
              Internal.C_API.Point_Polygon_Distance,
              "Signed_Distance_To_Contour"),
           "Signed_Distance_To_Contour result is not finite");
   begin
      if Points'Length > 0 and then abs Distance >= Distance_Search_Limit then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Signed_Distance_To_Contour distance reaches OpenCV's "
            & "Sqrt (FLT_MAX) search limit");
      end if;
      return Distance;
   end Signed_Distance_To_Contour;

   function Empty_Float32_Points return Float32_Point_Array is
      Empty : Float32_Point_Array (1 .. 0);
   begin
      return Empty;
   end Empty_Float32_Points;

   --  Converts a native zero-based offset to its index in Points'Range.
   function To_Public_Point_Index
     (Points    : Float32_Point_Array;
      Offset    : Interfaces.Integer_32;
      Operation : String) return Natural is
   begin
      if Points'Length = 0
        or else not Internal.Convexity.Is_Native_Offset
                      (Points'First, Points'Last, Offset)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation
            & " failed: native index"
            & Interfaces.Integer_32'Image (Offset)
            & " is outside the point set");
      end if;
      return
        Internal.Convexity.To_Point_Index (Points'First, Points'Last, Offset);
   end To_Public_Point_Index;

   function Convex_Hull
     (Points      : Float32_Point_Array;
      Orientation : Hull_Orientation := Counterclockwise)
      return Float32_Point_Array
   is
      Count  : aliased Interfaces.Integer_32 := 0;
      Status : Internal.C_API.Status;
   begin
      --  Native convexHull computes total + 2 in signed int.
      Validate_Native_Count
        (Points, Natural (Interfaces.Integer_32'Last) - 2, "Convex_Hull");
      Validate_Finite_Points (Points, "Convex_Hull");
      --  OpenCV compares binary32 coordinate differences.
      Validate_Binary32_Spans (Points, "Convex_Hull");
      if Points'Length = 0 then
         return Empty_Float32_Points;
      end if;

      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points, Positive_Zeros => True);
         --  Hull vertices are distinct input points.
         Output : aliased Internal.C_API.Point_F32_Array :=
           Output_Buffer (Points'Length);
      begin
         Status :=
           Internal.C_API.Convex_Hull_F32
             (First_Point (Packed),
              Point_Count (Packed),
              To_C_Clockwise (Orientation),
              First_Output (Output),
              Point_Count (Output),
              Count'Access);
         Raise_On_Error (Status, "convex hull");
         return
           Unpack_Float32_Points
             (Output,
              Checked_Count (Count, Output'Length, "convex hull"),
              "Convex_Hull");
      end;
   end Convex_Hull;

   function Convex_Hull_Indices
     (Points      : Float32_Point_Array;
      Orientation : Hull_Orientation := Counterclockwise)
      return Point_Index_Array
   is
      Count  : aliased Interfaces.Integer_32 := 0;
      Status : Internal.C_API.Status;
   begin
      Validate_Native_Count
        (Points,
         Natural (Interfaces.Integer_32'Last) - 2,
         "Convex_Hull_Indices");
      Validate_Finite_Points (Points, "Convex_Hull_Indices");
      Validate_Binary32_Spans (Points, "Convex_Hull_Indices");
      if Points'Length = 0 then
         return Empty_Point_Indices;
      end if;

      declare
         Packed     : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points, Positive_Zeros => True);
         --  Hull vertices are distinct input points.
         Output     : Internal.C_API.Int32_Array (0 .. Points'Length - 1);
         Hull_Count : Natural;
      begin
         Status :=
           Internal.C_API.Convex_Hull_Indices_F32
             (First_Point (Packed),
              Point_Count (Packed),
              To_C_Clockwise (Orientation),
              Output (Output'First)'Access,
              Interfaces.Integer_32 (Output'Length),
              Count'Access);
         Raise_On_Error (Status, "convex hull indices");
         Hull_Count :=
           Checked_Count (Count, Output'Length, "convex hull indices");
         if Hull_Count = 0 then
            return Empty_Point_Indices;
         end if;

         declare
            Result : Point_Index_Array (0 .. Hull_Count - 1);
         begin
            for Position in Result'Range loop
               Result (Position) :=
                 To_Public_Point_Index
                   (Points,
                    Output (Output'First + Position),
                    "convex hull indices");
            end loop;
            return Result;
         end;
      end;
   end Convex_Hull_Indices;

   function Approximate_Curve
     (Points  : Float32_Point_Array;
      Epsilon : OpenCV.Float64_Value;
      Closed  : Boolean) return Float32_Point_Array
   is
      use type OpenCV.Float64_Value;

      Count  : aliased Interfaces.Integer_32 := 0;
      Status : Internal.C_API.Status;
   begin
      if not Epsilon'Valid or else Epsilon < 0.0 or else Epsilon >= 1.0E30 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "approximate curve epsilon must be in the range "
            & "0.0 <= epsilon < 1.0E30");
      end if;
      Validate_Finite_Points (Points, "Approximate_Curve");
      if Points'Length = 0 then
         return Empty_Float32_Points;
      end if;
      --  An overflowing binary32 difference would make OpenCV drop points or,
      --  for Epsilon 0.0, read outside the curve without terminating.
      Validate_Binary32_Spans (Points, "Approximate_Curve");

      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
         --  The approximation is a subsequence of the input.
         Output : aliased Internal.C_API.Point_F32_Array :=
           Output_Buffer (Points'Length);
      begin
         Status :=
           Internal.C_API.Approximate_Curve_F32
             (First_Point (Packed),
              Point_Count (Packed),
              Interfaces.C.double (Epsilon),
              To_C_Boolean (Closed),
              First_Output (Output),
              Point_Count (Output),
              Count'Access);
         Raise_On_Error (Status, "approximate curve");
         return
           Unpack_Float32_Points
             (Output,
              Checked_Count (Count, Output'Length, "approximate curve"),
              "Approximate_Curve");
      end;
   end Approximate_Curve;

   function Minimum_Area_Rectangle
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect
   is
      --  To_Public_Rotated_Rect inspects the raw native fields.
      pragma Suppress (Validity_Check);
      Result : aliased Internal.C_API.C_Rotated_Rect :=
        (Center_X      => 0.0,
         Center_Y      => 0.0,
         Width         => 0.0,
         Height        => 0.0,
         Angle_Degrees => 0.0);
      Status : Internal.C_API.Status;
   begin
      Validate_Finite_Points (Points, "Minimum_Area_Rectangle");
      --  OpenCV allocates three binary32 values per hull vertex in signed
      --  32-bit arithmetic, and every point can be a hull vertex.
      Validate_Native_Count
        (Points,
         Natural (Interfaces.Integer_32'Last) / 3,
         "Minimum_Area_Rectangle");
      --  The hull compares binary32 coordinate differences.
      Validate_Binary32_Spans (Points, "Minimum_Area_Rectangle");
      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points, Positive_Zeros => True);
      begin
         Status :=
           Internal.C_API.Min_Area_Rect_F32
             (First_Point (Packed), Point_Count (Packed), Result'Access);
      end;
      Raise_On_Error (Status, "minimum area rectangle");
      return To_Public_Rotated_Rect (Result);
   end Minimum_Area_Rectangle;

   function Minimum_Enclosing_Circle
     (Points : Float32_Point_Array) return Enclosing_Circle
   is
      --  To_Public_Enclosing_Circle inspects the raw native fields.
      pragma Suppress (Validity_Check);
      Result : aliased Internal.C_API.C_Enclosing_Circle :=
        (Center_X => 0.0, Center_Y => 0.0, Radius => 0.0);
      Status : Internal.C_API.Status;
   begin
      Validate_Finite_Points (Points, "Minimum_Enclosing_Circle");
      --  OpenCV's circle through three points forms binary32 products of
      --  three coordinates; up to 2.0**41 they stay finite, so an overflow
      --  of the center or radius is infinite and raises below rather than
      --  making OpenCV 4.x silently keep a circle that misses a point.
      if Points'Length >= 3
        and then not Float32_Points.Magnitudes_Are_At_Most
                       (Points, Float32_Points.Circle_Coordinate_Limit)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Minimum_Enclosing_Circle requires coordinates of magnitude at "
            & "most 2.0**41 for three or more points");
      end if;
      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
      begin
         Status :=
           Internal.C_API.Min_Enclosing_Circle_F32
             (First_Point (Packed), Point_Count (Packed), Result'Access);
      end;
      Raise_On_Error (Status, "minimum enclosing circle");
      return To_Public_Enclosing_Circle (Result);
   end Minimum_Enclosing_Circle;

   type Float32_Ellipse_Fit is (Classic_Fit, AMS_Fit, Direct_Fit);

   --  Shared body of the Float32 ellipse fits: the integer overloads' count
   --  rules, plus the bound that keeps OpenCV's binary32 coordinate sums
   --  finite.
   function Fit_Float32_Ellipse
     (Points    : Float32_Point_Array;
      Fit       : Float32_Ellipse_Fit;
      Operation : String) return OpenCV.Rotated_Rect
   is
      --  To_Public_Rotated_Rect inspects the raw native fields.
      pragma Suppress (Validity_Check);
      Result : aliased Internal.C_API.C_Rotated_Rect :=
        (Center_X      => 0.0,
         Center_Y      => 0.0,
         Width         => 0.0,
         Height        => 0.0,
         Angle_Degrees => 0.0);
      Status : Internal.C_API.Status;
   begin
      if Points'Length < 5 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation & " requires at least five points");
      end if;
      --  OpenCV's classic fit, which every fit can reach, allocates
      --  n*12+n doubles with signed 32-bit arithmetic.
      Validate_Native_Count
        (Points, Natural (Interfaces.Integer_32'Last) / 13, Operation);
      Validate_Finite_Points (Points, Operation);
      if not Float32_Points.Coordinate_Sums_Are_Bounded (Points) then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            Operation
            & " requires the absolute X coordinates and the absolute Y "
            & "coordinates each to sum to at most 2.0**103");
      end if;

      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
      begin
         case Fit is
            when Classic_Fit =>
               Status :=
                 Internal.C_API.Fit_Ellipse_F32
                   (First_Point (Packed), Point_Count (Packed), Result'Access);

            when AMS_Fit     =>
               Status :=
                 Internal.C_API.Fit_Ellipse_AMS_F32
                   (First_Point (Packed), Point_Count (Packed), Result'Access);

            when Direct_Fit  =>
               Status :=
                 Internal.C_API.Fit_Ellipse_Direct_F32
                   (First_Point (Packed), Point_Count (Packed), Result'Access);
         end case;
      end;
      Raise_On_Error (Status, Operation);
      return To_Public_Rotated_Rect (Result);
   end Fit_Float32_Ellipse;

   function Fit_Ellipse
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect is
   begin
      return Fit_Float32_Ellipse (Points, Classic_Fit, "Fit_Ellipse");
   end Fit_Ellipse;

   function Fit_Ellipse_AMS
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect is
   begin
      return Fit_Float32_Ellipse (Points, AMS_Fit, "Fit_Ellipse_AMS");
   end Fit_Ellipse_AMS;

   function Fit_Ellipse_Direct
     (Points : Float32_Point_Array) return OpenCV.Rotated_Rect is
   begin
      return Fit_Float32_Ellipse (Points, Direct_Fit, "Fit_Ellipse_Direct");
   end Fit_Ellipse_Direct;

   function Fit_Line_2D
     (Points          : Float32_Point_Array;
      Distance        : Line_Fit_Distance := L2;
      Parameter       : OpenCV.Float64_Value := 0.0;
      Radius_Accuracy : OpenCV.Float64_Value := 0.01;
      Angle_Accuracy  : OpenCV.Float64_Value := 0.01) return Fitted_Line_2D
   is
      --  The scalars and the native line may be Inf/NaN; they are
      --  inspected before use.
      pragma Suppress (Validity_Check);
      use type OpenCV.Float32_Value;
      Result : aliased Internal.C_API.C_Line_2D :=
        (Direction_X => 0.0,
         Direction_Y => 0.0,
         Point_X     => 0.0,
         Point_Y     => 0.0);
      Status : Internal.C_API.Status;
      Line   : Fitted_Line_2D;
   begin
      if Points'Length = 0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Fit_Line_2D requires at least one point");
      end if;
      --  Native fitLine computes count*2 in signed int for the robust
      --  distances.
      if Distance /= L2 then
         Validate_Native_Count
           (Points, Natural (Interfaces.Integer_32'Last) / 2, "Fit_Line_2D");
      end if;
      Validate_Finite_Points (Points, "Fit_Line_2D");
      --  OpenCV forms the binary32 products X*X, Y*Y, and X*Y of raw
      --  coordinates; up to 2.0**63 they stay finite. An overflow of one
      --  axis alone would give a finite but wrong direction.
      if not Float32_Points.Magnitudes_Are_At_Most
               (Points, Float32_Points.Line_Coordinate_Limit)
      then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Fit_Line_2D requires coordinates of magnitude at most 2.0**63");
      end if;
      Validate_Line_Fit_Scalar (Parameter, "Parameter");
      Validate_Line_Fit_Scalar (Radius_Accuracy, "Radius_Accuracy");
      Validate_Line_Fit_Scalar (Angle_Accuracy, "Angle_Accuracy");

      declare
         Packed : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Points);
      begin
         Status :=
           Internal.C_API.Fit_Line_2D_F32
             (First_Point (Packed),
              Point_Count (Packed),
              To_C_Line_Fit_Distance (Distance),
              Interfaces.C.double (Parameter),
              Interfaces.C.double (Radius_Accuracy),
              Interfaces.C.double (Angle_Accuracy),
              Result'Access);
      end;
      Raise_On_Error (Status, "fit line 2D");
      Line :=
        (Direction =>
           (X =>
              To_Public_Float32
                (Result.Direction_X, "fitted line direction X is not finite"),
            Y =>
              To_Public_Float32
                (Result.Direction_Y, "fitted line direction Y is not finite")),
         Point     =>
           (X =>
              To_Public_Float32
                (Result.Point_X, "fitted line point X is not finite"),
            Y =>
              To_Public_Float32
                (Result.Point_Y, "fitted line point Y is not finite")));
      --  OpenCV's robust fit starts from an all-zero line and keeps it when
      --  no candidate line has a finite error.
      if Line.Direction.X = 0.0 and then Line.Direction.Y = 0.0 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Fit_Line_2D failed: OpenCV found no line with a finite error");
      end if;
      return Line;
   end Fit_Line_2D;

   --  The largest grid exponent at which every coordinate of Left and Right
   --  is a binary32-exact integer multiple of 2.0**Exponent. Larger
   --  exponents give smaller integer polygons, so if Left and Right are a
   --  power-of-two scaling of acceptable integer polygons at all, they are
   --  at this exponent. Raises OpenCV_Error when there is none.
   function Grid_Exponent_Of
     (Left, Right : Float32_Point_Array)
      return Internal.Intersection.Grid_Exponent
   is
      package Intersection renames Internal.Intersection;

      function On_Grid
        (Points : Float32_Point_Array; Exponent : Intersection.Grid_Exponent)
         return Boolean
      is (for all Point of Points =>
            Intersection.Is_Grid_Coordinate (Point.X, Exponent)
            and then Intersection.Is_Grid_Coordinate (Point.Y, Exponent));
   begin
      for Exponent in reverse Intersection.Grid_Exponent loop
         if On_Grid (Left, Exponent) and then On_Grid (Right, Exponent) then
            return Exponent;
         end if;
      end loop;
      Ada.Exceptions.Raise_Exception
        (OpenCV.OpenCV_Error'Identity,
         "Intersect_Convex_Polygons requires Left and Right coordinates on "
         & "one binary grid: integer multiples of 2.0**K, for some K in "
         & "-8 .. 6, of magnitude at most 2.0**(24 + K)");
   end Grid_Exponent_Of;

   --  Points divided by 2.0**Exponent, as an integer contour with the same
   --  bounds. Callers ensure that every coordinate is a grid coordinate.
   function To_Grid_Contour
     (Points   : Float32_Point_Array;
      Exponent : Internal.Intersection.Grid_Exponent) return Contour
   is
      Result : Contour (Points'Range);
   begin
      for Index in Points'Range loop
         Result (Index) :=
           (X =>
              Internal.Intersection.Grid_Coordinate
                (Points (Index).X, Exponent),
            Y =>
              Internal.Intersection.Grid_Coordinate
                (Points (Index).Y, Exponent));
      end loop;
      return Result;
   end To_Grid_Contour;

   function Intersect_Convex_Polygons
     (Left, Right : Float32_Point_Array; Handle_Nested : Boolean := True)
      return Convex_Polygon_Intersection is
   begin
      Validate_Finite_Points (Left, "Intersect_Convex_Polygons");
      Validate_Finite_Points (Right, "Intersect_Convex_Polygons");
      if Left'Length < 3 or else Right'Length < 3 then
         Ada.Exceptions.Raise_Exception
           (OpenCV.OpenCV_Error'Identity,
            "Intersect_Convex_Polygons requires Left and Right to have at "
            & "least three vertices");
      end if;

      --  Validate the integer polygons of which Left and Right are an exact
      --  power-of-two scaling, with the integer overload's rules; OpenCV's
      --  binary32 tests on Left and Right are then exactly as consistent.
      declare
         Exponent     : constant Internal.Intersection.Grid_Exponent :=
           Grid_Exponent_Of (Left, Right);
         Scaled_Left  : constant Contour := To_Grid_Contour (Left, Exponent);
         Scaled_Right : constant Contour := To_Grid_Contour (Right, Exponent);
      begin
         Validate_Convex_Polygon (Scaled_Left, "Left");
         Validate_Convex_Polygon (Scaled_Right, "Right");
         Validate_Exact_Spans
           (Scaled_Left,
            Scaled_Right,
            "at most 2.0**(24 + K) on their grid of multiples of 2.0**K, "
            & "or twice that when every coordinate is a multiple of "
            & "2.0**(K + 1)");
      end;
      Validate_Intersection_Counts (Left'Length, Right'Length);

      declare
         --  To_Public_Intersection inspects the raw native area and
         --  vertices.
         pragma Suppress (Validity_Check);
         Packed_Left  : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Left);
         Packed_Right : aliased constant Internal.C_API.Point_F32_Array :=
           Pack_Float32_Points (Right);
         Output       : aliased Internal.C_API.Point_F32_Array :=
           Output_Buffer
             (Internal.Intersection.Output_Capacity
                (Left'Length, Right'Length));
         Count        : aliased Interfaces.Integer_32 := 0;
         Area         : aliased Interfaces.C.C_float := 0.0;
         Status       : Internal.C_API.Status;
      begin
         Status :=
           Internal.C_API.Intersect_Convex_Convex_F32
             (First_Point (Packed_Left),
              Point_Count (Packed_Left),
              First_Point (Packed_Right),
              Point_Count (Packed_Right),
              To_C_Boolean (Handle_Nested),
              First_Output (Output),
              Point_Count (Output),
              Count'Access,
              Area'Access);
         Raise_On_Error (Status, "Intersect_Convex_Polygons");
         return To_Public_Intersection (Output, Count, Area);
      end;
   end Intersect_Convex_Polygons;
end OpenCV.Geometry;
