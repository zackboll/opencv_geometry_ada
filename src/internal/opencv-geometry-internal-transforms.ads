--  Pure Ada evaluation of Geometry-owned transform matrices at binary32
--  points. GNATprove proves that, under the preconditions below, the
--  binary64 evaluation cannot overflow and rounding to binary32 stays in
--  range. The non-SPARK public Transform_Point operations establish those
--  preconditions with run-time checks: they reject non-finite values and
--  coefficients above Coefficient_Limit before calling these helpers.

package OpenCV.Geometry.Internal.Transforms
  with SPARK_Mode => On
is

   subtype Float64 is OpenCV.Float64_Value;
   use type Float64;

   --  Every binary32 coordinate has magnitude below this bound.
   Coordinate_Limit : constant := 3.5E+38;

   --  A coefficient of at most this magnitude times a coordinate within
   --  Coordinate_Limit has magnitude at most 3.5E+307, so the sum of three
   --  such terms stays below binary64'Last (about 1.8E+308).
   Coefficient_Limit : constant := 1.0E+269;

   --  Magnitude bound for Linear_Form results.
   Form_Limit : constant := 1.1E+308;

   Binary32_Last : constant Float64 := Float64 (OpenCV.Float32_Value'Last);

   function Is_Bounded_Coefficient (Value : Float64) return Boolean
   is (Value in -Coefficient_Limit .. Coefficient_Limit)
   with Global => null;

   function Is_Binary32_Coordinate (Value : Float64) return Boolean
   is (Value in -Binary32_Last .. Binary32_Last)
   with Global => null;

   --  C0 * X + C1 * Y + C2, evaluated left to right in binary64.
   function Linear_Form (C0, C1, C2, X, Y : Float64) return Float64
   is (C0 * X + C1 * Y + C2)
   with
     Global => null,
     Pre    =>
       Is_Bounded_Coefficient (C0)
       and then Is_Bounded_Coefficient (C1)
       and then Is_Bounded_Coefficient (C2)
       and then Is_Binary32_Coordinate (X)
       and then Is_Binary32_Coordinate (Y),
     Post   => Linear_Form'Result in -Form_Limit .. Form_Limit;

   --  Divides only when the binary64 quotient cannot overflow, which covers
   --  every quotient of magnitude up to binary64'Last / 2; larger quotients
   --  are far outside binary32 range. Fits is True when the rounded binary64
   --  quotient lies within binary32 range, and False otherwise, in which case
   --  Quotient is 0.0.
   procedure Divide
     (Numerator, Denominator : Float64;
      Quotient               : out Float64;
      Fits                   : out Boolean)
   with
     Global => null,
     Pre    =>
       Numerator in -Form_Limit .. Form_Limit
       and then Denominator in -Form_Limit .. Form_Limit
       and then Denominator /= 0.0,
     Post   =>
       (if Fits
        then
          Quotient = Numerator / Denominator
          and then Is_Binary32_Coordinate (Quotient)
        else Quotient = 0.0);

   --  Rounds a value within binary32 range to the nearest binary32 value.
   function To_Binary32 (Value : Float64) return OpenCV.Float32_Value
   is (OpenCV.Float32_Value (Value))
   with Global => null, Pre => Is_Binary32_Coordinate (Value);

end OpenCV.Geometry.Internal.Transforms;
