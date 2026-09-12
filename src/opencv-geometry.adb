with Ada.Exceptions;
with Interfaces;
with Interfaces.C;
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
end OpenCV.Geometry;
