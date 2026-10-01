package body OpenCV.Geometry.Internal.Intersection
  with SPARK_Mode => On
is

   function Output_Capacity
     (Left_Length, Right_Length : Natural) return Natural is
   begin
      return Left_Length + Right_Length;
   end Output_Capacity;

   function Grid_Coordinate
     (Value : OpenCV.Float32_Value; Exponent : Grid_Exponent)
      return OpenCV.Point_Coordinate is
   begin
      return OpenCV.Point_Coordinate (Grid_Scaled (Value, Exponent));
   end Grid_Coordinate;

end OpenCV.Geometry.Internal.Intersection;
