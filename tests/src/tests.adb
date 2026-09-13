with Ada.Command_Line;
with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with AUnit.Test_Suites;
with Approximate_Curve_Tests;
with Bounding_Rect_Tests;
with Contour_Geometry_Tests;
with Contour_Moments_Tests;
with Convex_Hull_Tests;
with Is_Convex_Tests;
with Hu_Moments_Tests;
with Match_Shapes_Tests;
with Point_Polygon_Tests;
with Minimum_Enclosing_Circle_Tests;

procedure Tests is

   use type AUnit.Status;

   Suite : constant AUnit.Test_Suites.Access_Test_Suite :=
     Contour_Geometry_Tests.Suite;

   function Stored_Suite return AUnit.Test_Suites.Access_Test_Suite
   is (Suite);

   function Run is new AUnit.Run.Test_Runner_With_Status (Stored_Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   Suite.Add_Test (Contour_Moments_Tests.Suite);
   Suite.Add_Test (Convex_Hull_Tests.Suite);
   Suite.Add_Test (Approximate_Curve_Tests.Suite);
   Suite.Add_Test (Bounding_Rect_Tests.Suite);
   Suite.Add_Test (Is_Convex_Tests.Suite);
   Suite.Add_Test (Hu_Moments_Tests.Suite);
   Suite.Add_Test (Match_Shapes_Tests.Suite);
   Suite.Add_Test (Point_Polygon_Tests.Suite);
   Suite.Add_Test (Minimum_Enclosing_Circle_Tests.Suite);
   if Run (Reporter) = AUnit.Failure then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
