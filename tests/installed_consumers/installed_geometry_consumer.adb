with Ada.Command_Line;
with Ada.Text_IO;
with Geometry_Consumer_Checks;

--  Independent Ada application built only against the installed
--  opencv_core and opencv_geometry projects.
procedure Installed_Geometry_Consumer is
begin
   if Geometry_Consumer_Checks.Run = 0 then
      Ada.Text_IO.Put_Line ("consumer PASS installed Ada");
   else
      Ada.Text_IO.Put_Line ("consumer FAIL installed Ada");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Installed_Geometry_Consumer;
