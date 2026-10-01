package body OpenCV.Geometry.Internal.Transforms
  with SPARK_Mode => On
is

   Half_Binary64_Last : constant Float64 := Float64'Last / 2.0;

   procedure Divide
     (Numerator, Denominator : Float64;
      Quotient               : out Float64;
      Fits                   : out Boolean) is
   begin
      Quotient := 0.0;
      Fits := False;

      if abs Denominator >= 1.0 then
         --  Dividing by a magnitude of at least one cannot increase the
         --  numerator's magnitude.
         Quotient := Numerator / Denominator;
      elsif abs Numerator <= Half_Binary64_Last * abs Denominator then
         --  The exact quotient is at most about binary64'Last / 2, so the
         --  rounded quotient is finite.
         Quotient := Numerator / Denominator;
      else
         --  The quotient exceeds binary64'Last / 2, far outside binary32.
         return;
      end if;

      if Is_Binary32_Coordinate (Quotient) then
         Fits := True;
      else
         Quotient := 0.0;
      end if;
   end Divide;

end OpenCV.Geometry.Internal.Transforms;
