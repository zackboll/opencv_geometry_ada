package body OpenCV.Geometry.Internal.Intersection
  with SPARK_Mode => On
is

   function Output_Capacity
     (Left_Length, Right_Length : Natural) return Natural is
   begin
      return Left_Length + Right_Length;
   end Output_Capacity;

end OpenCV.Geometry.Internal.Intersection;
