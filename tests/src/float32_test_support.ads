with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;

--  Shared helpers for the tests of the Float32 point-set overloads.

package Float32_Test_Support is

   subtype Points is OpenCV.Geometry.Float32_Point_Array;

   --  IEEE special values; callers suppress validity checks.
   function NaN_32 return OpenCV.Float32_Value;
   function Infinity_32 return OpenCV.Float32_Value;
   function Negative_Infinity_32 return OpenCV.Float32_Value;

   --  -0.0, which a static Ada expression cannot produce.
   function Negative_Zero_32 return OpenCV.Float32_Value;

   --  True when Value is -0.0.
   function Is_Negative_Zero (Value : OpenCV.Float32_Value) return Boolean;

   --  A quiet NaN for raw C ABI buffers.
   function NaN_C return Interfaces.C.C_float;

   --  Source with each coordinate rounded to the nearest integer. For
   --  integer-valued Source this is the same point set as an integer
   --  contour, preserving bounds and order.
   function Rounded (Source : Points) return OpenCV.Geometry.Contour;

   --  Source converted to binary32 points with the same bounds and order.
   function To_Float32 (Source : OpenCV.Geometry.Contour) return Points;

   --  True when Source holds a point equal to Item.
   function Contains_Point
     (Source : Points; Item : OpenCV.Float32_Point) return Boolean;

   --  True when Left and Right have the same length and every point of
   --  each occurs in the other.
   function Same_Vertex_Set (Left, Right : Points) return Boolean;

   --  True when Right is a cyclic rotation of Left.
   function Same_Cyclic_Order (Left, Right : Points) return Boolean;

   --  Source packed in iteration order into a zero-based raw C ABI buffer
   --  with at least one element; pass Source'Length as the count.
   function Pack
     (Source : Points) return OpenCV.Geometry.Internal.C_API.Point_F32_Array;

   procedure Assert_Raises_OpenCV_Error
     (Attempt : not null access procedure; Message : String);

   --  Calls Operation on copies of Base in which one coordinate of the
   --  first or last point is NaN, +Inf, or -Inf, and asserts that each call
   --  raises OpenCV_Error rather than Constraint_Error.
   procedure Assert_Rejects_Non_Finite
     (Base      : Points;
      Operation : not null access procedure (Candidate : Points);
      Name      : String)
   with Pre => Base'Length > 0;

end Float32_Test_Support;
