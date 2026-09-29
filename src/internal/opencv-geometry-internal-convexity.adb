package body OpenCV.Geometry.Internal.Convexity
  with SPARK_Mode => On
is

   --  Multiplying by a nonnegative factor preserves order.
   procedure Lemma_Multiply_Monotonic (Factor, Low, High : Long_Long_Integer)
   with
     Ghost,
     Global => null,
     Pre    =>
       Factor in 0 .. Maximum_Defect_Extent
       and then Low in 0 .. Maximum_Defect_Extent
       and then High in Low .. Maximum_Defect_Extent,
     Post   => Factor * Low <= Factor * High;

   procedure Lemma_Multiply_Monotonic (Factor, Low, High : Long_Long_Integer)
   is null;

   function To_Point_Index
     (First, Last : Natural; Offset : Interfaces.Integer_32) return Natural is
   begin
      pragma Assert (Long_Long_Integer (Offset) <= Long_Long_Integer (Last));
      return Natural (Long_Long_Integer (First) + Long_Long_Integer (Offset));
   end To_Point_Index;

   function To_Native_Offset
     (First, Last, Index : Natural) return Interfaces.Integer_32 is
   begin
      pragma Assert (Index <= Last);
      return
        Interfaces.Integer_32
          (Long_Long_Integer (Index) - Long_Long_Integer (First));
   end To_Native_Offset;

   procedure Lemma_Monotonic_Hull_Length
     (First, Last : Natural; Hull : Point_Index_Array) is
   begin
      if Hull'Length = 0 then
         return;
      end if;
      pragma
        Assert
          (Hull (Hull'First) in First .. Last
             and then Hull (Hull'Last) in First .. Last);

      if Is_Strictly_Increasing (Hull) then
         for Position in Hull'Range loop
            pragma
              Loop_Invariant
                (for all Earlier in Hull'First .. Position =>
                   Long_Long_Integer (Hull (Earlier))
                   - Long_Long_Integer (Hull (Hull'First))
                   >= Long_Long_Integer (Earlier)
                      - Long_Long_Integer (Hull'First));
         end loop;
         pragma
           Assert
             (Long_Long_Integer (Hull (Hull'Last))
                - Long_Long_Integer (Hull (Hull'First))
                >= Long_Long_Integer (Hull'Last)
                   - Long_Long_Integer (Hull'First));
      else
         for Position in Hull'Range loop
            pragma
              Loop_Invariant
                (for all Earlier in Hull'First .. Position =>
                   Long_Long_Integer (Hull (Hull'First))
                   - Long_Long_Integer (Hull (Earlier))
                   >= Long_Long_Integer (Earlier)
                      - Long_Long_Integer (Hull'First));
         end loop;
         pragma
           Assert
             (Long_Long_Integer (Hull (Hull'First))
                - Long_Long_Integer (Hull (Hull'Last))
                >= Long_Long_Integer (Hull'Last)
                   - Long_Long_Integer (Hull'First));
      end if;
   end Lemma_Monotonic_Hull_Length;

   function Bounds_Of (Points : OpenCV.Point_Array) return Coordinate_Bounds is
      Result : Coordinate_Bounds :=
        (Min_X => Points (Points'First).X,
         Max_X => Points (Points'First).X,
         Min_Y => Points (Points'First).Y,
         Max_Y => Points (Points'First).Y);
   begin
      for Position in Points'Range loop
         if Points (Position).X < Result.Min_X then
            Result.Min_X := Points (Position).X;
         end if;
         if Points (Position).X > Result.Max_X then
            Result.Max_X := Points (Position).X;
         end if;
         if Points (Position).Y < Result.Min_Y then
            Result.Min_Y := Points (Position).Y;
         end if;
         if Points (Position).Y > Result.Max_Y then
            Result.Max_Y := Points (Position).Y;
         end if;

         pragma Loop_Invariant (Is_Ordered (Result));
         pragma
           Loop_Invariant
             (for all Earlier in Points'First .. Position =>
                Contains (Result, Points (Earlier)));
         pragma
           Loop_Invariant
             (for some Earlier in Points'First .. Position =>
                Points (Earlier).X = Result.Min_X);
         pragma
           Loop_Invariant
             (for some Earlier in Points'First .. Position =>
                Points (Earlier).X = Result.Max_X);
         pragma
           Loop_Invariant
             (for some Earlier in Points'First .. Position =>
                Points (Earlier).Y = Result.Min_Y);
         pragma
           Loop_Invariant
             (for some Earlier in Points'First .. Position =>
                Points (Earlier).Y = Result.Max_Y);
      end loop;
      return Result;
   end Bounds_Of;

   procedure Lemma_Pair_Within_Defect_Extent
     (Bounds : Coordinate_Bounds; Left, Right : OpenCV.Point)
   is
      Width   : constant Long_Long_Integer :=
        Span (Bounds.Min_X, Bounds.Max_X);
      Height  : constant Long_Long_Integer :=
        Span (Bounds.Min_Y, Bounds.Max_Y);
      Delta_X : constant Long_Long_Integer :=
        Long_Long_Integer (Left.X) - Long_Long_Integer (Right.X);
      Delta_Y : constant Long_Long_Integer :=
        Long_Long_Integer (Left.Y) - Long_Long_Integer (Right.Y);
      Size_X  : constant Long_Long_Integer := abs Delta_X;
      Size_Y  : constant Long_Long_Integer := abs Delta_Y;
   begin
      pragma Assert (Size_X <= Width);
      pragma Assert (Size_Y <= Height);
      Lemma_Multiply_Monotonic (Size_X, Size_X, Width);
      Lemma_Multiply_Monotonic (Width, Size_X, Width);
      pragma Assert (Size_X * Size_X <= Width * Width);
      Lemma_Multiply_Monotonic (Size_Y, Size_Y, Height);
      Lemma_Multiply_Monotonic (Height, Size_Y, Height);
      pragma Assert (Size_Y * Size_Y <= Height * Height);
      pragma Assert (Delta_X * Delta_X = Size_X * Size_X);
      pragma Assert (Delta_Y * Delta_Y = Size_Y * Size_Y);
   end Lemma_Pair_Within_Defect_Extent;

end OpenCV.Geometry.Internal.Convexity;
