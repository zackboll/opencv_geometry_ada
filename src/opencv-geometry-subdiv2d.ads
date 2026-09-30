private with Ada.Finalization;
private with OpenCV.Geometry.Internal.C_API;

--  Planar subdivision: an incremental Delaunay triangulation of points in
--  an integer bounding rectangle, backed by one native cv::Subdiv2D.
--
--  Ownership: a Subdivision exclusively owns its native object. The type is
--  limited, so assignment cannot duplicate ownership, and finalization
--  releases the native object deterministically. No native handle is
--  visible to callers.
--
--  Thread safety: a Subdivision must not be used by more than one task at a
--  time, including for query-only calls. OpenCV mutates internal state in
--  Locate (a cached search start) and Find_Nearest (Voronoi data whose
--  computation can reallocate storage), so concurrent calls on one object
--  can corrupt it or read freed memory. Distinct objects are independent.
--
--  Identifiers: Vertex_Id and Edge_Id are native OpenCV identifiers, and
--  they are meaningful only for the Subdivision that produced them. A vertex
--  identifier of an inserted point stays valid until the next Reset. An edge
--  identifier stays valid only until the next Insert or Reset: insertion
--  flips edges and reuses edge slots, so an older identifier can name a
--  different edge. Vertex identifiers are not dense: OpenCV reserves 0 for
--  "no vertex" and 1 .. 3 for the virtual vertices of a bounding
--  super-triangle, and Voronoi computation in Find_Nearest also occupies
--  identifiers, so inserted points need not receive consecutive ids.
--
--  Bounds are an integer OpenCV.Rect, which every supported OpenCV release
--  accepts; the binary32 Rect2f initialization that only OpenCV 4.13+ and
--  5.x provide is not offered.
--
--  Scale: OpenCV's geometric predicates use absolute tolerances near
--  FLT_EPSILON, whatever the coordinate magnitude, so results depend on the
--  spacing of the inserted points (the smallest distance between two of
--  them). The triangulation is reliably Delaunay only when that spacing is
--  at least about 0.03 units. Below it, measured on OpenCV 4.10 and 5.0,
--  with rates that depend on how the points are distributed:
--  - Find_Nearest can return a vertex that is not nearest (a few percent
--    at a spacing of 0.01 units or less, and up to about 30% at 0.003
--    units or less), or raise OpenCV.OpenCV_Error because OpenCV reports
--    no vertex;
--  - Insert and Locate can raise OpenCV.OpenCV_Error because OpenCV cannot
--    locate a point;
--  - at about 0.0001 units, Find_Nearest can fail to return, because
--    OpenCV's facet walk is unbounded and the binding cannot interrupt it.
--  Scale coordinates so that distinct points lie well apart.

package OpenCV.Geometry.Subdiv2D is

   type Subdivision is limited private;

   type Vertex_Id is range 0 .. 2**31 - 1;

   No_Vertex : constant Vertex_Id := 0;

   type Edge_Id is range 0 .. 2**31 - 1;

   No_Edge : constant Edge_Id := 0;

   --  A new Subdivision holding an empty Delaunay triangulation of Bounds,
   --  as if by Reset.
   function Create (Bounds : OpenCV.Rect) return Subdivision;

   --  Discards every point and initializes Object to an empty Delaunay
   --  triangulation of Bounds, creating its native object when needed.
   --  Bounds.Width and Bounds.Height must be positive. OpenCV accepts points
   --  in the half-open region X >= Bounds.X, X < Bounds.X + Bounds.Width,
   --  and likewise for Y, with both limits computed in binary32. Zero
   --  dimensions and native failures raise OpenCV.OpenCV_Error; after a
   --  native failure Object is not ready.
   procedure Reset (Object : in out Subdivision; Bounds : OpenCV.Rect);

   --  True when Object owns a native subdivision that accepts operations.
   --  False for an object that has never been Reset or Created, and after an
   --  operation that failed while modifying the triangulation, such as an
   --  insertion that exhausted memory, left it possibly inconsistent. Only
   --  Reset makes such an object ready again. Insert, Locate, and
   --  Find_Nearest on an object that is not ready raise OpenCV.OpenCV_Error.
   function Is_Ready (Object : Subdivision) return Boolean;

   --  Bounds of the last successful Reset or Create. Raises
   --  OpenCV.OpenCV_Error when there has been none.
   function Bounds (Object : Subdivision) return OpenCV.Rect;

   --  Inserts Point into the triangulation and returns its vertex. A point
   --  that OpenCV finds coincident with an existing vertex (binary32 L1
   --  distance below FLT_EPSILON from an endpoint of the edge where it is
   --  located) returns that vertex and adds nothing. Point must be finite
   --  and inside the bounds. A point outside the bounds, or a point that
   --  OpenCV cannot locate, raises OpenCV.OpenCV_Error and leaves the
   --  triangulation unchanged and Object ready.
   function Insert
     (Object : in out Subdivision; Point : OpenCV.Float32_Point)
      return Vertex_Id;

   --  Inserts Points in iteration order, as repeated single insertions. Every
   --  coordinate is checked for finiteness before any point is inserted. When
   --  OpenCV rejects a point, for example because it lies outside the bounds,
   --  the points before it remain inserted and OpenCV.OpenCV_Error is raised.
   procedure Insert
     (Object : in out Subdivision; Points : Float32_Point_Array);

   type Point_Location_Kind is (Inside_Facet, On_Edge, On_Vertex);

   --  Where a point lies in the triangulation:
   --  - Inside_Facet: inside the facet on the left of Edge. That facet can
   --    include virtual super-triangle vertices, as it does in a
   --    subdivision without points.
   --  - On_Edge: on Edge.
   --  - On_Vertex: at Vertex.
   type Locate_Result (Kind : Point_Location_Kind := Inside_Facet) is record
      case Kind is
         when Inside_Facet | On_Edge =>
            Edge : Edge_Id;

         when On_Vertex =>
            Vertex : Vertex_Id;
      end case;
   end record;

   --  Locates Point, which must be finite and inside the bounds. OpenCV
   --  raises an error for a point outside the bounds instead of returning its
   --  PTLOC_OUTSIDE_RECT classification, so such points raise
   --  OpenCV.OpenCV_Error, as does a search that does not converge. Locate
   --  updates OpenCV's cached search start, so the edge reported for a point
   --  can differ between calls.
   function Locate
     (Object : in out Subdivision; Point : OpenCV.Float32_Point)
      return Locate_Result;

   --  An inserted vertex and its position.
   type Nearest_Result is record
      Vertex : Vertex_Id := No_Vertex;
      Point  : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
   end record;

   --  The inserted vertex whose Voronoi facet contains Point, which is a
   --  nearest inserted vertex up to rounding for points spaced as the
   --  package's Scale note requires, and its position. Point must be finite
   --  and inside the bounds. Raises OpenCV.OpenCV_Error when no point has
   --  been inserted, and when OpenCV reports no vertex, which can happen for
   --  points closer than the package's Scale note requires; Object stays
   --  ready. Find_Nearest computes Voronoi data inside Object when earlier
   --  insertions invalidated it. For points about 0.0001 units apart it can
   --  fail to return (see Scale).
   function Find_Nearest
     (Object : in out Subdivision; Point : OpenCV.Float32_Point)
      return Nearest_Result;

private

   type Subdivision is new Ada.Finalization.Limited_Controlled with record
      Handle     : Internal.C_API.Subdiv2D_Handle := null;
      Bounds     : OpenCV.Rect := (X => 0, Y => 0, Width => 0, Height => 0);
      Has_Bounds : Boolean := False;
   end record;

   overriding
   procedure Finalize (Object : in out Subdivision);

end OpenCV.Geometry.Subdiv2D;
