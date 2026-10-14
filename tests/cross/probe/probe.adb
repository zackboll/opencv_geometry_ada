with Interfaces.C;

procedure Probe is
   use type Interfaces.C.int;

   function Cxx_Probe (Count : Interfaces.C.int) return Interfaces.C.int
   with Import, Convention => C, External_Name => "geometry_cross_cxx_probe";
begin
   if Cxx_Probe (3) /= 6 then
      raise Program_Error with "C++ probe returned an unexpected value";
   end if;
end Probe;
