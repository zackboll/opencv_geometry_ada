with Interfaces;

--  Pure Ada capacity bounds for Subdiv2D list results, derived from the
--  loops of cv::Subdiv2D::getEdgeList, getLeadingEdgeList, and
--  getTriangleList in OpenCV 4.6, 4.10, and 5.0.

package OpenCV.Geometry.Internal.Subdivision
  with SPARK_Mode => On
is

   --  The shim refuses any insertion that would take the native quad-edge
   --  count above Integer_32'Last / 4 - 16, and initialization creates four
   --  slots, so a reported count never exceeds this bound.
   Maximum_Quad_Edges : constant :=
     Interfaces.Integer_32'Pos (Interfaces.Integer_32'Last) / 4 - 16;

   subtype Quad_Edge_Count is Natural range 0 .. Maximum_Quad_Edges;

   --  getEdgeList emits at most one segment per quad-edge slot from slot 4.
   function Edge_List_Capacity (Count : Quad_Edge_Count) return Natural
   is (if Count > 4 then Count - 4 else 0)
   with Global => null, Post => Edge_List_Capacity'Result <= Count;

   --  getLeadingEdgeList and getTriangleList visit edge identifiers 4, 6,
   --  ..., 4 * Count - 2 and emit at most one element for each.
   function Facet_List_Capacity (Count : Quad_Edge_Count) return Natural
   is (if Count > 1 then 2 * Count - 2 else 0)
   with Global => null, Post => Facet_List_Capacity'Result <= 2 * Count;

end OpenCV.Geometry.Internal.Subdivision;
