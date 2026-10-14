--  Checks shared by the independent installed-consumer applications. They
--  use only the public opencv_geometry and opencv_core APIs, as an
--  application would, and report each result on standard output.
package Geometry_Consumer_Checks is

   --  Runs every check and returns the number that failed.
   function Run return Natural;

   --  Records one named check; used by the mixed consumer for its own
   --  native comparison.
   procedure Check (Condition : Boolean; Name : String);

   --  Failures recorded by Check since the program started.
   function Failures return Natural;

end Geometry_Consumer_Checks;
