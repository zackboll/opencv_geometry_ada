with Ada.Unchecked_Conversion;
with AUnit.Assertions;
with Interfaces;

package body Float32_Test_Support is

   use type OpenCV.Float32_Value;

   function Bits_To_Float32 is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => OpenCV.Float32_Value);

   function NaN_32 return OpenCV.Float32_Value is
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float32 (16#7FC0_0000#);
   end NaN_32;

   function Infinity_32 return OpenCV.Float32_Value is
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float32 (16#7F80_0000#);
   end Infinity_32;

   function Negative_Infinity_32 return OpenCV.Float32_Value is
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_Float32 (16#FF80_0000#);
   end Negative_Infinity_32;

   function Negative_Zero_32 return OpenCV.Float32_Value is
   begin
      return Bits_To_Float32 (16#8000_0000#);
   end Negative_Zero_32;

   function Float32_To_Bits is new
     Ada.Unchecked_Conversion
       (Source => OpenCV.Float32_Value,
        Target => Interfaces.Unsigned_32);

   function Is_Negative_Zero (Value : OpenCV.Float32_Value) return Boolean is
      use type Interfaces.Unsigned_32;
   begin
      return Float32_To_Bits (Value) = 16#8000_0000#;
   end Is_Negative_Zero;

   function Bits_To_C_Float is new
     Ada.Unchecked_Conversion
       (Source => Interfaces.Unsigned_32,
        Target => Interfaces.C.C_float);

   function NaN_C return Interfaces.C.C_float is
      pragma Suppress (Validity_Check);
   begin
      return Bits_To_C_Float (16#7FC0_0000#);
   end NaN_C;

   function Rounded (Source : Points) return OpenCV.Geometry.Contour is
      Result : OpenCV.Geometry.Contour (Source'Range);
   begin
      for Index in Source'Range loop
         Result (Index) :=
           (X => OpenCV.Point_Coordinate (Source (Index).X),
            Y => OpenCV.Point_Coordinate (Source (Index).Y));
      end loop;
      return Result;
   end Rounded;

   function To_Float32 (Source : OpenCV.Geometry.Contour) return Points is
      Result : Points (Source'Range);
   begin
      for Index in Source'Range loop
         Result (Index) :=
           (X => OpenCV.Float32_Value (Source (Index).X),
            Y => OpenCV.Float32_Value (Source (Index).Y));
      end loop;
      return Result;
   end To_Float32;

   function Contains_Point
     (Source : Points; Item : OpenCV.Float32_Point) return Boolean is
   begin
      for Point of Source loop
         if Point.X = Item.X and then Point.Y = Item.Y then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Point;

   function Same_Vertex_Set (Left, Right : Points) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;
      for Point of Left loop
         if not Contains_Point (Right, Point) then
            return False;
         end if;
      end loop;
      for Point of Right loop
         if not Contains_Point (Left, Point) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Vertex_Set;

   function Same_Cyclic_Order (Left, Right : Points) return Boolean is
      Count : constant Natural := Left'Length;
   begin
      if Right'Length /= Count then
         return False;
      end if;
      for Shift in 0 .. Count - 1 loop
         declare
            Matches : Boolean := True;
         begin
            for Offset in 0 .. Count - 1 loop
               declare
                  L : OpenCV.Float32_Point renames Left (Left'First + Offset);
                  R : OpenCV.Float32_Point renames
                    Right (Right'First + (Offset + Shift) mod Count);
               begin
                  if L.X /= R.X or else L.Y /= R.Y then
                     Matches := False;
                     exit;
                  end if;
               end;
            end loop;
            if Matches then
               return True;
            end if;
         end;
      end loop;
      return Count = 0;
   end Same_Cyclic_Order;

   function Pack
     (Source : Points) return OpenCV.Geometry.Internal.C_API.Point_F32_Array
   is
      Result :
        OpenCV.Geometry.Internal.C_API.Point_F32_Array
          (0 .. Natural'Max (Source'Length, 1) - 1) :=
          (others => (X => 0.0, Y => 0.0));
   begin
      for Offset in 0 .. Source'Length - 1 loop
         Result (Offset) :=
           (X => Interfaces.C.C_float (Source (Source'First + Offset).X),
            Y => Interfaces.C.C_float (Source (Source'First + Offset).Y));
      end loop;
      return Result;
   end Pack;

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

   procedure Assert_Rejects_Non_Finite
     (Base      : Points;
      Operation : not null access procedure (Candidate : Points);
      Name      : String)
   is
      --  The candidates hold NaN and infinities by design.
      pragma Suppress (Validity_Check);

      type Special_Kind is (Quiet_NaN, Positive_Infinity, Negative_Infinity);
      type Axis is (X_Axis, Y_Axis);

      function Special (Kind : Special_Kind) return OpenCV.Float32_Value
      is (case Kind is
            when Quiet_NaN         => NaN_32,
            when Positive_Infinity => Infinity_32,
            when Negative_Infinity => Negative_Infinity_32);

      Positions : constant array (1 .. 2) of Natural :=
        (Base'First, Base'Last);
   begin
      for Kind in Special_Kind loop
         for Position of Positions loop
            for Coordinate in Axis loop
               declare
                  Candidate : Points := Base;
                  Raised    : Boolean := False;
                  Label     : constant String :=
                    Name
                    & " "
                    & Kind'Image
                    & " "
                    & Coordinate'Image
                    & " at"
                    & Position'Image;
               begin
                  case Coordinate is
                     when X_Axis =>
                        Candidate (Position).X := Special (Kind);

                     when Y_Axis =>
                        Candidate (Position).Y := Special (Kind);
                  end case;
                  begin
                     Operation (Candidate);
                  exception
                     when OpenCV.OpenCV_Error =>
                        Raised := True;

                     when Constraint_Error =>
                        AUnit.Assertions.Assert
                          (False, Label & " raised Constraint_Error");
                  end;
                  AUnit.Assertions.Assert
                    (Raised, Label & " must raise OpenCV_Error");
               end;
            end loop;
         end loop;
      end loop;
   end Assert_Rejects_Non_Finite;

end Float32_Test_Support;
