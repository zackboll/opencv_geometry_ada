package body OpenCV.Geometry.Internal.Float32_Points
  with SPARK_Mode => On
is

   function Floor_Of (Value : Float32) return Long_Long_Integer is
      Floor : constant Float32 := Float32'Floor (Value);
   begin
      pragma Assert (Floor >= -Int32_Conversion_Limit);
      pragma Assert (Floor < Int32_Conversion_Limit);
      return Long_Long_Integer (Floor);
   end Floor_Of;

   function Bounds_Of (Points : Float32_Point_Array) return Coordinate_Bounds
   is
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

end OpenCV.Geometry.Internal.Float32_Points;
