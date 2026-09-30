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
--  Locate (a cached search start), and in Find_Nearest and Voronoi_Facets
--  (Voronoi data whose computation can reallocate storage), so concurrent
--  calls on one object can corrupt it or read freed memory. Distinct
--  objects are independent.
--
--  Identifiers: Vertex_Id and Edge_Id are native OpenCV identifiers, and
--  they are meaningful only for the Subdivision that produced them. A vertex
--  identifier of an inserted point stays valid until the next Reset. An edge
--  identifier stays valid only until the next Insert or Reset: insertion
--  flips edges and reuses edge slots, so an older identifier can name a
--  different edge. Vertex identifiers are not dense: OpenCV reserves 0 for
--  "no vertex" and 1 .. 3 for the vertices of a bounding super-triangle,
--  and Voronoi computation in Find_Nearest and Voronoi_Facets also
--  occupies identifiers, so inserted points need not receive consecutive
--  ids.
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
   --  Reset makes such an object ready again. Every other operation on a
   --  Subdivision except Bounds raises OpenCV.OpenCV_Error when the object
   --  is not ready.
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
   --    include super-triangle vertices, as it does in a subdivision without
   --    points.
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

   --  Extraction. Results are Ada-owned values indexed 1 .. N, in native
   --  order, and stay valid whatever later happens to Object. Each call
   --  raises OpenCV.OpenCV_Error when Object is not ready.

   --  A Delaunay edge as the positions of its origin and destination.
   type Edge_Segment is record
      Origin      : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
      Destination : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
   end record;

   type Edge_Segment_Array is array (Natural range <>) of Edge_Segment;

   type Edge_Id_Array is array (Natural range <>) of Edge_Id;

   type Triangle_Array is
     array (Natural range <>) of OpenCV.Geometry.Triangle_Vertices;

   --  Every Delaunay edge once, as by cv::Subdiv2D::getEdgeList. The list
   --  includes edges to the super-triangle vertices, whose positions lie
   --  outside the bounds, but not the super-triangle's own three edges.
   function Edge_List (Object : Subdivision) return Edge_Segment_Array;

   --  One edge of every triangular facet, as by getLeadingEdgeList, with the
   --  facet on its left, so three Next_Around_Left steps return to it. The
   --  facets include those with super-triangle vertices and the facet outside
   --  the super-triangle.
   function Leading_Edge_List (Object : Subdivision) return Edge_Id_Array;

   --  Every triangle whose three vertices all lie in the half-open bounds, as
   --  by getTriangleList, so triangles with a super-triangle vertex are
   --  excluded. Near the convex hull the reported triangles can differ
   --  between OpenCV releases: 4.12 and later, including 5.x, use a
   --  super-triangle twice as large as earlier releases.
   function Triangle_List (Object : Subdivision) return Triangle_Array;

   --  Navigation. Each operation takes identifiers produced by Object and
   --  raises OpenCV.OpenCV_Error for No_Vertex or a free vertex slot, for
   --  No_Edge or the other identifiers 1 .. 3 of OpenCV's reserved null
   --  edge, for an identifier beyond native storage, and when Object is not
   --  ready. Edges are directed. An Edge_Id names a Delaunay edge, or, after
   --  a Rotated_Edge or Reversed_Rotated_Edge rotation, its dual Voronoi edge.

   --  The eight related edges of cv::Subdiv2D::getEdge. For a Delaunay edge
   --  E the quad-edge structure gives these identities, which the binding's
   --  tests check on every supported release:
   --  - Next_Around_Origin (NEXT_AROUND_ORG, OpenCV's eOnext) and
   --    Previous_Around_Origin (PREV_AROUND_ORG) share E's origin;
   --  - Next_Around_Destination (NEXT_AROUND_DST, eDnext) and
   --    Previous_Around_Destination (PREV_AROUND_DST) share E's destination;
   --  - Next_Around_Left (NEXT_AROUND_LEFT, eLnext) and Previous_Around_Right
   --    (PREV_AROUND_RIGHT) start at E's destination;
   --  - Next_Around_Right (NEXT_AROUND_RIGHT, eRnext) and
   --    Previous_Around_Left (PREV_AROUND_LEFT) end at E's origin;
   --  - each Next choice and the matching Previous choice undo each other.
   type Edge_Navigation is
     (Next_Around_Origin,
      Next_Around_Destination,
      Previous_Around_Origin,
      Previous_Around_Destination,
      Next_Around_Left,
      Next_Around_Right,
      Previous_Around_Left,
      Previous_Around_Right);

   --  The four edges of one quad-edge, as by cv::Subdiv2D::rotateEdge:
   --  Same_Edge is E itself, Rotated_Edge its dual (OpenCV's eRot), directed
   --  from the facet on E's right to the facet on its left, Reversed_Edge E
   --  with origin and destination swapped, and Reversed_Rotated_Edge the
   --  reversed dual. Four Rotated_Edge rotations return E.
   type Edge_Rotation is
     (Same_Edge, Rotated_Edge, Reversed_Edge, Reversed_Rotated_Edge);

   --  The edge related to Edge by Direction, as by getEdge.
   function Navigate
     (Object : Subdivision; Edge : Edge_Id; Direction : Edge_Navigation)
      return Edge_Id;

   --  The next edge around Edge's origin, as by nextEdge; the same as
   --  Navigate (Object, Edge, Next_Around_Origin).
   function Next_Edge (Object : Subdivision; Edge : Edge_Id) return Edge_Id;

   --  The edge of Edge's quad-edge selected by Rotation, as by rotateEdge.
   function Rotate
     (Object : Subdivision; Edge : Edge_Id; Rotation : Edge_Rotation)
      return Edge_Id;

   --  Edge with origin and destination swapped, as by symEdge; the same as
   --  Rotate (Object, Edge, Reversed_Edge).
   function Symmetric_Edge
     (Object : Subdivision; Edge : Edge_Id) return Edge_Id;

   --  The origin and destination vertices of Edge, as by edgeOrg and edgeDst.
   --  For a dual Voronoi edge they are the Voronoi vertices (circumcenters)
   --  of the facets it joins, which Find_Nearest and Voronoi_Facets compute
   --  and which are meaningful only until the next Insert. The result is
   --  No_Vertex before any Voronoi computation, and for a facet that OpenCV
   --  gives no Voronoi vertex: the facet outside the super-triangle, so one
   --  end of the dual of each super-triangle edge, and a degenerate facet
   --  whose circumcenter OpenCV cannot represent.
   function Origin (Object : Subdivision; Edge : Edge_Id) return Vertex_Id;

   function Destination
     (Object : Subdivision; Edge : Edge_Id) return Vertex_Id;

   --  The position of Vertex, as by getVertex: an inserted point, one of the
   --  super-triangle vertices (identifiers 1 .. 3, outside the bounds), or a
   --  Voronoi vertex. Voronoi vertex positions are meaningful only until
   --  the next Insert.
   function Vertex_Point
     (Object : Subdivision; Vertex : Vertex_Id) return OpenCV.Float32_Point;

   --  An edge whose origin is Vertex, as recorded by OpenCV (getVertex's
   --  firstEdge), or No_Edge for a Voronoi vertex.
   function First_Edge
     (Object : Subdivision; Vertex : Vertex_Id) return Edge_Id;

   --  Voronoi diagram. OpenCV computes the Voronoi diagram of the inserted
   --  points together with the three super-triangle vertices. The facet of
   --  an inserted point, its site, is the region nearer to that point than
   --  to any other of those vertices. So for points spaced as the package's
   --  Scale note requires, each Voronoi vertex of a facet is nearest to its
   --  site among the inserted points, up to rounding. A facet whose true
   --  Voronoi region reaches beyond the super-triangle, as the region of
   --  every point on the convex hull and of some points near it does, is
   --  closed by circumcenters of triangles with a super-triangle vertex.
   --  Those lie far outside the bounds and differ between releases, because
   --  4.12 and later, including 5.x, use a larger super-triangle.
   --
   --  Like Find_Nearest, these functions compute Voronoi data inside Object
   --  when earlier insertions invalidated it. Each raises OpenCV.OpenCV_Error
   --  when Object is not ready; a native failure leaves Object ready.

   type Vertex_Id_Array is array (Natural range <>) of Vertex_Id;

   --  One facet of a Voronoi_Diagram: Site, its position Site_Point (OpenCV's
   --  facet center), and the facet polygon, which is the diagram's
   --  Points (First .. Last) in the order of OpenCV's walk around Site.
   --
   --  Complete is False when OpenCV computed no Voronoi vertex for part of
   --  the facet. That happens next to a degenerate (collinear) triangle,
   --  which OpenCV's absolute tolerances can leave among points closer than
   --  the Scale note requires; probes found such triangles among points
   --  between about 0.0001 and 0.003 units apart, depending on how the
   --  points are distributed. OpenCV then reports the origin (0.0, 0.0) in
   --  place of each missing Voronoi vertex, and the polygon keeps those
   --  placeholder points, so an incomplete polygon is not the true facet.
   type Voronoi_Facet is record
      Site       : Vertex_Id := No_Vertex;
      Site_Point : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
      First      : Positive := 1;
      Last       : Natural := 0;
      Complete   : Boolean := True;
   end record;

   type Voronoi_Facet_Array is array (Natural range <>) of Voronoi_Facet;

   --  Facets indexed 1 .. Facet_Count and their points indexed
   --  1 .. Point_Count. The facet polygons are consecutive, nonempty slices
   --  of Points that follow facet order and together cover Points.
   type Voronoi_Diagram (Facet_Count, Point_Count : Natural) is record
      Facets : Voronoi_Facet_Array (1 .. Facet_Count);
      Points : Float32_Point_Array (1 .. Point_Count);
   end record;

   --  The polygon of Diagram.Facets (Index), indexed 1 .. N. Raises
   --  Constraint_Error when Index or that facet's slice lies outside Diagram.
   function Facet_Points
     (Diagram : Voronoi_Diagram; Index : Positive) return Float32_Point_Array;

   --  The facet of every inserted point, once each and in increasing Site
   --  order, as by cv::Subdiv2D::getVoronoiFacetList for every vertex. An
   --  object without inserted points gives an empty diagram.
   function Voronoi_Facets
     (Object : in out Subdivision) return Voronoi_Diagram;

   --  The facets of Sites, in order and once per occurrence, as by
   --  getVoronoiFacetList with Sites as its index list. Each element must be
   --  the vertex of an inserted point. No_Vertex, the super-triangle
   --  vertices 1 .. 3, free slots, Voronoi vertices, and identifiers beyond
   --  native storage raise OpenCV.OpenCV_Error. Unlike OpenCV, which treats
   --  an empty index list as every vertex, empty Sites give an empty
   --  diagram.
   function Voronoi_Facets
     (Object : in out Subdivision; Sites : Vertex_Id_Array)
      return Voronoi_Diagram;

private

   type Subdivision is new Ada.Finalization.Limited_Controlled with record
      Handle     : Internal.C_API.Subdiv2D_Handle := null;
      Bounds     : OpenCV.Rect := (X => 0, Y => 0, Width => 0, Height => 0);
      Has_Bounds : Boolean := False;
   end record;

   overriding
   procedure Finalize (Object : in out Subdivision);

end OpenCV.Geometry.Subdiv2D;
