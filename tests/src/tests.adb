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
with Convex_Hull_Indices_Tests;
with Convexity_Defects_Tests;
with Float32_Approximate_Curve_Tests;
with Float32_Contour_Geometry_Tests;
with Float32_Convex_Hull_Tests;
with Float32_Enclosing_Tests;
with Float32_Fit_Tests;
with Float32_Moments_Tests;
with Float32_Point_Polygon_Tests;
with Is_Convex_Tests;
with Hu_Moments_Tests;
with Match_Shapes_Tests;
with Point_Polygon_Tests;
with Minimum_Enclosing_Circle_Tests;
with Minimum_Enclosing_Triangle_Tests;
with Minimum_Area_Rectangle_Tests;
with Fit_Ellipse_Tests;
with Fit_Ellipse_Variants_Tests;
with Fit_Line_2D_Tests;
with Box_Points_Tests;
with Convex_Polygon_Intersection_Tests;
with Rotated_Rectangle_Intersection_Tests;
with Rotation_Matrix_Tests;
with Affine_Transform_Tests;
with Perspective_Transform_Tests;
with Subdiv2D_Foundation_Tests;
with Subdiv2D_Navigation_Tests;
with Subdiv2D_Voronoi_Tests;

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
   Suite.Add_Test (Convex_Hull_Indices_Tests.Suite);
   Suite.Add_Test (Convexity_Defects_Tests.Suite);
   Suite.Add_Test (Approximate_Curve_Tests.Suite);
   Suite.Add_Test (Bounding_Rect_Tests.Suite);
   Suite.Add_Test (Is_Convex_Tests.Suite);
   Suite.Add_Test (Hu_Moments_Tests.Suite);
   Suite.Add_Test (Match_Shapes_Tests.Suite);
   Suite.Add_Test (Point_Polygon_Tests.Suite);
   Suite.Add_Test (Minimum_Enclosing_Circle_Tests.Suite);
   Suite.Add_Test (Minimum_Enclosing_Triangle_Tests.Suite);
   Suite.Add_Test (Minimum_Area_Rectangle_Tests.Suite);
   Suite.Add_Test (Fit_Ellipse_Tests.Suite);
   Suite.Add_Test (Fit_Ellipse_Variants_Tests.Suite);
   Suite.Add_Test (Fit_Line_2D_Tests.Suite);
   Suite.Add_Test (Box_Points_Tests.Suite);
   Suite.Add_Test (Convex_Polygon_Intersection_Tests.Suite);
   Suite.Add_Test (Rotated_Rectangle_Intersection_Tests.Suite);
   Suite.Add_Test (Rotation_Matrix_Tests.Suite);
   Suite.Add_Test (Affine_Transform_Tests.Suite);
   Suite.Add_Test (Perspective_Transform_Tests.Suite);
   Suite.Add_Test (Subdiv2D_Foundation_Tests.Suite);
   Suite.Add_Test (Subdiv2D_Navigation_Tests.Suite);
   Suite.Add_Test (Subdiv2D_Voronoi_Tests.Suite);
   Suite.Add_Test (Float32_Contour_Geometry_Tests.Suite);
   Suite.Add_Test (Float32_Moments_Tests.Suite);
   Suite.Add_Test (Float32_Point_Polygon_Tests.Suite);
   Suite.Add_Test (Float32_Convex_Hull_Tests.Suite);
   Suite.Add_Test (Float32_Approximate_Curve_Tests.Suite);
   Suite.Add_Test (Float32_Enclosing_Tests.Suite);
   Suite.Add_Test (Float32_Fit_Tests.Suite);
   if Run (Reporter) = AUnit.Failure then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
