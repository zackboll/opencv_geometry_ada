private with Ada.Finalization;
private with OpenCV.Geometry.Internal.C_API;

--  Planar subdivision: an incremental Delaunay triangulation of points in
--  an integer or binary32 bounding rectangle, backed by one cv::Subdiv2D.
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
--  "no vertex" and 1 .. 3 for the initial bounding super-triangle vertices.
--  Voronoi computation in Find_Nearest and Voronoi_Facets also creates
--  virtual vertices, so inserted points need not receive consecutive ids.
--
--  Integer bounds are available on every supported release. Float32 bounds
--  use Create_Float32 / Reset_Float32 on every supported release, without
--  integer rounding. References below to Reset's invalidation and
--  recovery behavior also apply to Reset_Float32.
--
--  Scale: OpenCV's geometric predicates use absolute tolerances near
--  FLT_EPSILON. Numerical behavior depends on coordinate scale and geometric
--  conditioning, not just the smallest distance between inserted points.
--  In specific random-point and jittered-grid probes on OpenCV 4.10 and 5.0,
--  no Find_Nearest failures were observed at spacings of about 0.03 units
--  or more. At 0.01 units or less, a few percent of answers were not nearest
--  or OpenCV reported no vertex; at 0.003 or less, up to about 30% were
--  wrong. At about 0.0001 units, Insert and Locate could fail to locate
--  points and Find_Nearest could fail to return. These are observations for
--  those distributions, not a guaranteed safe minimum: near-collinear or
--  nearly cocircular sets may behave differently at any pairwise spacing.
--  Scale geometry so distinct features are comfortably separated relative
--  to OpenCV's binary32 predicates.
--
--  Extraction. Results are Ada-owned arrays indexed 1 .. N, in native
--  order. Edge_List and Triangle_List contain copied values that remain
--  valid independently of later changes to Object. Leading_Edge_List
--  storage remains safely allocated, but its Edge_Id elements are valid
--  only until the next Insert or Reset of Object. Each call raises
--  OpenCV.OpenCV_Error when Object is not ready.
--
--  Navigation. Each operation takes identifiers produced by Object and
--  raises OpenCV.OpenCV_Error for No_Vertex or a free vertex slot, for
--  No_Edge or the other identifiers 1 .. 3 of OpenCV's reserved null
--  edge, for an identifier beyond native storage, and when Object is not
--  ready. Edges are directed. An Edge_Id names a Delaunay edge, or, after
--  a Rotated_Edge or Reversed_Rotated_Edge rotation, its dual Voronoi edge.
--
--  Voronoi diagram. OpenCV computes the Voronoi diagram of the inserted
--  points together with the three super-triangle vertices. The facet of
--  an inserted point, its site, is the region nearer to that point than
--  to any other of those vertices. In tested well-spaced fixtures, each
--  facet point was nearest to its site among inserted points, up to
--  rounding. This is not guaranteed by a minimum spacing: conditioning,
--  including near-collinear and nearly cocircular sets, also matters.
--  A facet whose true Voronoi region reaches beyond the super-triangle, as
--  the region of every point on the convex hull and of some points near it
--  does, is closed by circumcenters of triangles with a super-triangle
--  vertex. Those lie far outside the bounds and differ between releases,
--  because 4.12 and later, including 5.x, use a larger super-triangle.
--
--  Like Find_Nearest, both Voronoi_Facets functions compute Voronoi data
--  inside Object when earlier insertions invalidated it. Each raises
--  OpenCV.OpenCV_Error when Object is not ready; a native failure leaves
--  Object ready.

package OpenCV.Geometry.Subdiv2D is

   --  An incremental Delaunay triangulation that exclusively owns one native
   --  cv::Subdiv2D. It is limited, so it cannot be copied; finalization
   --  releases the native object. A declared object is not ready until
   --  Create, Create_Float32, Reset or Reset_Float32 succeeds. A
   --  Subdivision must not be used by more than one task at a time, even
   --  for query-only operations; distinct objects are independent.
   type Subdivision is limited private;

   --  Axis-aligned binary32 initialization descriptor, not a rotated rect.
   --  @field X Left edge: the smallest accepted X.
   --  @field Y Top edge: the smallest accepted Y.
   --  @field Width Extent in X; must be positive.
   --  @field Height Extent in Y; must be positive.
   type Float32_Rectangle is record
      X      : OpenCV.Float32_Value := 0.0;
      Y      : OpenCV.Float32_Value := 0.0;
      Width  : OpenCV.Float32_Value := 0.0;
      Height : OpenCV.Float32_Value := 0.0;
   end record;

   --  Native OpenCV vertex identifier, meaningful only for the Subdivision
   --  that produced it (see the package description for its lifetime).
   type Vertex_Id is range 0 .. 2**31 - 1;

   --  OpenCV's "no vertex" identifier, never a real vertex.
   No_Vertex : constant Vertex_Id := 0;

   --  Native OpenCV directed-edge identifier, meaningful only for the
   --  Subdivision that produced it and only until its next Insert or Reset.
   type Edge_Id is range 0 .. 2**31 - 1;

   --  OpenCV's "no edge" identifier, part of its reserved null quad-edge.
   No_Edge : constant Edge_Id := 0;

   --  A new Subdivision holding an empty Delaunay triangulation of Bounds,
   --  as if by Reset.
   --  @param Bounds Integer bounds, with the rules of Reset.
   --  @return A ready subdivision without inserted points.
   --  @exception OpenCV_Error Bounds that Reset rejects, or a native
   --    allocation or initialization failure.
   function Create (Bounds : OpenCV.Rect) return Subdivision;

   --  A new subdivision as if by Reset_Float32. The distinct name preserves
   --  integer Create calls with unqualified rectangle aggregates.
   --  @param Bounds Binary32 bounds, with the rules of Reset_Float32.
   --  @return A ready subdivision without inserted points.
   --  @exception OpenCV_Error Bounds that Reset_Float32 rejects, or a native
   --    allocation or initialization failure.
   function Create_Float32 (Bounds : Float32_Rectangle) return Subdivision;

   --  Discards every point and initializes Object to an empty Delaunay
   --  triangulation of Bounds, creating its native object when needed.
   --  Bounds.Width and Bounds.Height must be positive. OpenCV accepts points
   --  in the half-open region X >= Bounds.X, X < Bounds.X + Bounds.Width,
   --  and likewise for Y, with both limits computed in binary32 after native
   --  conversion of each integer field. Positive dimensions that disappear
   --  in this addition are rejected. Initialization arithmetic must produce
   --  finite upper limits and super-triangle coordinates. Semantic rejection
   --  leaves Object unchanged; native failure leaves it not ready. Neither
   --  failure publishes new bounds. Failures raise OpenCV.OpenCV_Error.
   --  Every vertex and edge identifier of Object becomes invalid.
   --  @param Object The subdivision to (re)initialize; it need not be ready.
   --  @param Bounds Integer bounds with positive Width and Height.
   --  @exception OpenCV_Error Bounds rejected by the rules above (Object
   --    unchanged), or a native allocation or initialization failure (Object
   --    not ready).
   procedure Reset (Object : in out Subdivision; Bounds : OpenCV.Rect);

   --  As above, without rounding to integers. OpenCV 4.6 .. 4.12 uses a
   --  private initialization backport; 4.13+ and 5.x call native Rect2f.
   --  Is_Natively_Supported still reports native Rect2f availability only.
   --  All fields must be finite; Width and Height must be positive and their
   --  binary32 additions to X/Y must advance. `Big = 6 * max (Width,
   --  Height)` and X/Y +/- Big must remain finite. These conditions also
   --  guarantee a distinguishable, nondegenerate initial super-triangle, but
   --  not good conditioning of subsequent native geometric predicates.
   --  @param Object The subdivision to (re)initialize; it need not be ready.
   --  @param Bounds Binary32 bounds satisfying the rules above.
   --  @exception OpenCV_Error Bounds rejected by the rules above (Object
   --    unchanged), or a native allocation or initialization failure (Object
   --    not ready).
   procedure Reset_Float32
     (Object : in out Subdivision; Bounds : Float32_Rectangle);

   --  True when Object owns a native subdivision that accepts operations.
   --  False for an object that has never been Reset or Created, and after an
   --  operation that failed while modifying the triangulation, such as an
   --  insertion that exhausted memory, left it possibly inconsistent. Only
   --  Reset makes such an object ready again. Every other operation on a
   --  Subdivision except the bounds queries raises OpenCV.OpenCV_Error when
   --  the object is not ready.
   --  @param Object The subdivision to query.
   --  @return Whether Object can be used by the other operations.
   function Is_Ready (Object : Subdivision) return Boolean;

   --  Original integer bounds of the last successful initialization. Raises
   --  OpenCV.OpenCV_Error when there has been none or Float32 bounds were
   --  supplied. Never silently rounds or encloses a Float32 rectangle.
   --  @param Object The subdivision to query; it need not be ready.
   --  @return The Bounds passed to the last successful Create or Reset.
   --  @exception OpenCV_Error No successful initialization yet, or the last
   --    one used Float32 bounds.
   function Bounds (Object : Subdivision) return OpenCV.Rect;

   --  Exact descriptor of the last successful initialization: the supplied
   --  Float32 rectangle, or each integer field converted as native OpenCV
   --  does. Upper limits are still computed by binary32 addition. Available
   --  on all releases, including after a failed native Reset; raises
   --  OpenCV.OpenCV_Error only when initialization has never succeeded.
   --  @param Object The subdivision to query; it need not be ready.
   --  @return The binary32 bounds of the last successful initialization.
   --  @exception OpenCV_Error No initialization has succeeded yet.
   function Bounds_Float32 (Object : Subdivision) return Float32_Rectangle;

   --  Inserts Point into the triangulation and returns its vertex. A point
   --  that OpenCV finds coincident with an existing vertex (binary32 L1
   --  distance below FLT_EPSILON from an endpoint of the edge where it is
   --  located) returns that vertex and adds nothing. Point must be finite
   --  and inside the bounds. A point outside the bounds, or a point that
   --  OpenCV cannot locate, raises OpenCV.OpenCV_Error and leaves the
   --  triangulation unchanged and Object ready. Every edge identifier of
   --  Object, and every Voronoi vertex, becomes invalid.
   --  @param Object A ready subdivision.
   --  @param Point The point to insert; finite and inside the bounds.
   --  @return The vertex of Point, or of the existing coincident vertex.
   --  @exception OpenCV_Error A non-finite Point, an Object that is not
   --    ready, a point outside the bounds or that OpenCV cannot locate, or
   --    another native failure (after which Object may be not ready).
   function Insert
     (Object : in out Subdivision; Point : OpenCV.Float32_Point)
      return Vertex_Id;

   --  Inserts Points in iteration order, as repeated single insertions. Every
   --  coordinate is checked for finiteness before any point is inserted. When
   --  OpenCV rejects a point, for example because it lies outside the bounds,
   --  the points before it remain inserted and OpenCV.OpenCV_Error is raised.
   --  The insertion is therefore not atomic; the exception message names the
   --  index of the rejected point. Vertex identifiers are not returned: use
   --  the single-point Insert, Locate or Find_Nearest to obtain them.
   --  @param Object A ready subdivision.
   --  @param Points The points to insert, with any bounds; may be empty.
   --  @exception OpenCV_Error A non-finite coordinate (before any insertion),
   --    an Object that is not ready, or a rejected point, after which the
   --    earlier points remain inserted.
   procedure Insert
     (Object : in out Subdivision; Points : Float32_Point_Array);

   --  Classification of a located point.
   --  @enum Inside_Facet Strictly inside a facet (PTLOC_INSIDE).
   --  @enum On_Edge On an edge (PTLOC_ON_EDGE).
   --  @enum On_Vertex At an existing vertex (PTLOC_VERTEX).
   type Point_Location_Kind is (Inside_Facet, On_Edge, On_Vertex);

   --  Where a point lies in the triangulation:
   --  - Inside_Facet: inside the facet on the left of Edge. That facet can
   --    include reserved super-triangle vertices, as it does in a
   --    subdivision without points.
   --  - On_Edge: on Edge.
   --  - On_Vertex: at Vertex.
   --  @field Kind The classification, which selects the component.
   --  @field Edge For Inside_Facet, an edge with the facet on its left; for
   --    On_Edge, the edge containing the point.
   --  @field Vertex For On_Vertex, the vertex at the point.
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
   --  @param Object A ready subdivision; its cached search start changes.
   --  @param Point The point to locate; finite and inside the bounds.
   --  @return The classification with its edge, valid until the next Insert
   --    or Reset, or its vertex, valid until the next Reset.
   --  @exception OpenCV_Error A non-finite Point, an Object that is not
   --    ready, a point outside the bounds, a search that does not converge,
   --    or another native failure.
   function Locate
     (Object : in out Subdivision; Point : OpenCV.Float32_Point)
      return Locate_Result;

   --  An inserted vertex and its position.
   --  @field Vertex The vertex identifier.
   --  @field Point The vertex position, as OpenCV stores it.
   type Nearest_Result is record
      Vertex : Vertex_Id := No_Vertex;
      Point  : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
   end record;

   --  The inserted vertex whose Voronoi facet contains Point, normally the
   --  nearest inserted vertex up to rounding, and its position. Numerical
   --  conditioning can affect this result (see Scale). Point must be finite
   --  and inside the bounds. Raises OpenCV.OpenCV_Error when no point has
   --  been inserted or when OpenCV reports no vertex; Object stays ready.
   --  Find_Nearest computes Voronoi data inside Object when earlier
   --  insertions invalidated it. It enters native OpenCV synchronously:
   --  cv::Subdiv2D::findNearest has an unbounded facet walk, and some
   --  numerically pathological triangulations can cause it not to return.
   --  The Ada binding cannot interrupt or recover from a native call that
   --  does not return. Reset can recover after a returned failure, but not
   --  while execution is stuck inside OpenCV. Callers requiring a hard
   --  liveness or deadline guarantee must not rely on Find_Nearest for
   --  untrusted or poorly conditioned geometry.
   --  @param Object A ready subdivision with at least one inserted point; its
   --    Voronoi data may be recomputed.
   --  @param Point The query point; finite and inside the bounds.
   --  @return The vertex whose Voronoi facet contains Point, with its
   --    position, when the native call returns. This is not proved to be the
   --    nearest inserted vertex.
   --  @exception OpenCV_Error A non-finite Point, an Object that is not
   --    ready, no inserted point, OpenCV reporting no vertex, or another
   --    native failure that returns; a call that does not return raises
   --    nothing.
   function Find_Nearest
     (Object : in out Subdivision; Point : OpenCV.Float32_Point)
      return Nearest_Result;

   --  A Delaunay edge as the positions of its origin and destination.
   --  @field Origin Position of the edge's origin vertex.
   --  @field Destination Position of the edge's destination vertex.
   type Edge_Segment is record
      Origin      : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
      Destination : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
   end record;

   --  Copied Delaunay edges, as returned by Edge_List.
   type Edge_Segment_Array is array (Natural range <>) of Edge_Segment;

   --  Edge identifiers, as returned by Leading_Edge_List; each is valid only
   --  until the next Insert or Reset of the subdivision that produced it.
   type Edge_Id_Array is array (Natural range <>) of Edge_Id;

   --  Copied triangles, as returned by Triangle_List.
   type Triangle_Array is
     array (Natural range <>) of OpenCV.Geometry.Triangle_Vertices;

   --  Every Delaunay edge once, as by cv::Subdiv2D::getEdgeList. The list
   --  includes edges to the super-triangle vertices, whose positions lie
   --  outside the bounds, but not the super-triangle's own three edges.
   --  @param Object A ready subdivision.
   --  @return The edges in native order, indexed 1 .. N, as copied values
   --    that stay valid after later changes to Object.
   --  @exception OpenCV_Error An Object that is not ready, an invalid native
   --    count, or another native failure.
   function Edge_List (Object : Subdivision) return Edge_Segment_Array;

   --  One edge of every triangular facet, as by getLeadingEdgeList, with the
   --  facet on its left, so three Next_Around_Left steps return to it. The
   --  facets include those with super-triangle vertices and the facet outside
   --  the super-triangle.
   --  @param Object A ready subdivision.
   --  @return The leading edges in native order, indexed 1 .. N. The array
   --    is Ada-owned, but its identifiers are valid only until the next
   --    Insert or Reset of Object.
   --  @exception OpenCV_Error An Object that is not ready, an invalid native
   --    count or edge, or another native failure.
   function Leading_Edge_List (Object : Subdivision) return Edge_Id_Array;

   --  Every triangle whose three vertices all lie in the half-open bounds, as
   --  by getTriangleList, so triangles with a super-triangle vertex are
   --  excluded. Near the convex hull the reported triangles can differ
   --  between OpenCV releases: 4.12 and later, including 5.x, use a
   --  super-triangle twice as large as earlier releases.
   --  @param Object A ready subdivision.
   --  @return The triangles in native order, indexed 1 .. N, as copied
   --    vertex positions that stay valid after later changes to Object.
   --  @exception OpenCV_Error An Object that is not ready, an invalid native
   --    count, or another native failure.
   function Triangle_List (Object : Subdivision) return Triangle_Array;

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
   --  @enum Next_Around_Origin NEXT_AROUND_ORG (eOnext): the next edge
   --    around E's origin, sharing that origin.
   --  @enum Next_Around_Destination NEXT_AROUND_DST (eDnext): the next edge
   --    around E's destination, sharing that destination.
   --  @enum Previous_Around_Origin PREV_AROUND_ORG: the previous edge around
   --    E's origin; it undoes Next_Around_Origin.
   --  @enum Previous_Around_Destination PREV_AROUND_DST: the previous edge
   --    around E's destination; it undoes Next_Around_Destination.
   --  @enum Next_Around_Left NEXT_AROUND_LEFT (eLnext): the next edge
   --    around E's left facet, starting at E's destination.
   --  @enum Next_Around_Right NEXT_AROUND_RIGHT (eRnext): the next edge
   --    around E's right facet, ending at E's origin.
   --  @enum Previous_Around_Left PREV_AROUND_LEFT: the previous edge around
   --    E's left facet, ending at E's origin; it undoes Next_Around_Left.
   --  @enum Previous_Around_Right PREV_AROUND_RIGHT: the previous edge
   --    around E's right facet, starting at E's destination; it undoes
   --    Next_Around_Right.
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
   --  @enum Same_Edge The edge E itself.
   --  @enum Rotated_Edge The dual edge of E (OpenCV's eRot).
   --  @enum Reversed_Edge E with origin and destination swapped, as by
   --    symEdge.
   --  @enum Reversed_Rotated_Edge The reversed dual edge of E.
   type Edge_Rotation is
     (Same_Edge, Rotated_Edge, Reversed_Edge, Reversed_Rotated_Edge);

   --  The edge related to Edge by Direction, as by getEdge.
   --  @param Object A ready subdivision.
   --  @param Edge An edge identifier produced by Object, at least 4.
   --  @param Direction The related edge to select.
   --  @return The related edge, valid until the next Insert or Reset.
   --  @exception OpenCV_Error An identifier of the reserved null edge, one
   --    beyond native storage, an Object that is not ready, OpenCV
   --    returning no edge, or another native failure.
   function Navigate
     (Object : Subdivision; Edge : Edge_Id; Direction : Edge_Navigation)
      return Edge_Id;

   --  The next edge around Edge's origin, as by nextEdge; the same as
   --  Navigate (Object, Edge, Next_Around_Origin).
   --  @param Object A ready subdivision.
   --  @param Edge An edge identifier produced by Object, at least 4.
   --  @return The next edge around the origin, valid until the next Insert
   --    or Reset.
   --  @exception OpenCV_Error As for Navigate.
   function Next_Edge (Object : Subdivision; Edge : Edge_Id) return Edge_Id;

   --  The edge of Edge's quad-edge selected by Rotation, as by rotateEdge.
   --  @param Object A ready subdivision.
   --  @param Edge An edge identifier produced by Object, at least 4.
   --  @param Rotation Which of the four quad-edge members to return.
   --  @return The selected edge, valid until the next Insert or Reset.
   --  @exception OpenCV_Error As for Navigate.
   function Rotate
     (Object : Subdivision; Edge : Edge_Id; Rotation : Edge_Rotation)
      return Edge_Id;

   --  Edge with origin and destination swapped, as by symEdge; the same as
   --  Rotate (Object, Edge, Reversed_Edge).
   --  @param Object A ready subdivision.
   --  @param Edge An edge identifier produced by Object, at least 4.
   --  @return The reversed edge, valid until the next Insert or Reset.
   --  @exception OpenCV_Error As for Navigate.
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
   --  @param Object A ready subdivision.
   --  @param Edge An edge identifier produced by Object, at least 4.
   --  @return The origin vertex of Edge, or No_Vertex as described above.
   --  @exception OpenCV_Error An identifier of the reserved null edge, one
   --    beyond native storage, an Object that is not ready, an invalid
   --    native vertex, or another native failure.
   function Origin (Object : Subdivision; Edge : Edge_Id) return Vertex_Id;

   --  The destination vertex of Edge, as by edgeDst, with the same meaning
   --  for dual Voronoi edges and the same No_Vertex cases as Origin.
   --  @param Object A ready subdivision.
   --  @param Edge An edge identifier produced by Object, at least 4.
   --  @return The destination vertex of Edge, or No_Vertex as for Origin.
   --  @exception OpenCV_Error As for Origin.
   function Destination
     (Object : Subdivision; Edge : Edge_Id) return Vertex_Id;

   --  The position of Vertex, as by getVertex: an inserted point, one of the
   --  super-triangle vertices (identifiers 1 .. 3, outside the bounds), or a
   --  Voronoi vertex. Voronoi vertex positions are meaningful only until
   --  the next Insert.
   --  @param Object A ready subdivision.
   --  @param Vertex An occupied vertex slot of Object; not No_Vertex.
   --  @return The vertex position, as OpenCV stores it.
   --  @exception OpenCV_Error No_Vertex, a free slot, an identifier beyond
   --    native storage, an Object that is not ready, or another native
   --    failure.
   function Vertex_Point
     (Object : Subdivision; Vertex : Vertex_Id) return OpenCV.Float32_Point;

   --  An edge whose origin is Vertex, as recorded by OpenCV (getVertex's
   --  firstEdge), or No_Edge for a Voronoi vertex.
   --  @param Object A ready subdivision.
   --  @param Vertex An occupied vertex slot of Object; not No_Vertex.
   --  @return An edge leaving Vertex, valid until the next Insert or Reset,
   --    or No_Edge.
   --  @exception OpenCV_Error As for Vertex_Point, or an invalid native edge.
   function First_Edge
     (Object : Subdivision; Vertex : Vertex_Id) return Edge_Id;

   --  Vertex identifiers, such as the Sites of a Voronoi_Facets request.
   type Vertex_Id_Array is array (Natural range <>) of Vertex_Id;

   --  One facet of a Voronoi_Diagram: Site, its position Site_Point (OpenCV's
   --  facet center), and the facet polygon, which is the diagram's
   --  Points (First .. Last) in the order of OpenCV's walk around Site.
   --
   --  Complete is False when OpenCV failed to create at least one Voronoi
   --  vertex for the facet, for example because degenerate or ill-conditioned
   --  geometry makes a circumcenter impossible to compute or represent in
   --  OpenCV's accepted finite binary32 range. Probes found missing vertices
   --  among points about 0.0001 to 0.003 units apart, depending on their
   --  distribution; these spacings are observations, not hard thresholds.
   --  OpenCV then reports the origin (0.0, 0.0) in place of each missing
   --  vertex, and the polygon keeps those placeholder points, so an
   --  incomplete polygon is not the true facet.
   --  @field Site The inserted point's vertex identifier.
   --  @field Site_Point The site's position, OpenCV's facet center.
   --  @field First Index in the diagram's Points of the polygon's first point.
   --  @field Last Index in the diagram's Points of the polygon's last point;
   --    at least First in a returned diagram.
   --  @field Complete False when the polygon holds placeholder points for
   --    Voronoi vertices that OpenCV failed to create.
   type Voronoi_Facet is record
      Site       : Vertex_Id := No_Vertex;
      Site_Point : OpenCV.Float32_Point := (X => 0.0, Y => 0.0);
      First      : Positive := 1;
      Last       : Natural := 0;
      Complete   : Boolean := True;
   end record;

   --  The facets of a Voronoi_Diagram, in diagram order.
   type Voronoi_Facet_Array is array (Natural range <>) of Voronoi_Facet;

   --  Facets indexed 1 .. Facet_Count and their points indexed
   --  1 .. Point_Count. The facet polygons are consecutive, nonempty slices
   --  of Points that follow facet order and together cover Points. The
   --  diagram is an Ada-owned copy; its Site identifiers follow the
   --  Vertex_Id lifetime rules, and positions near the super-triangle
   --  depend on the OpenCV release.
   --  @field Facet_Count Number of facets.
   --  @field Point_Count Total number of polygon points of all facets.
   --  @field Facets The facets, indexed 1 .. Facet_Count.
   --  @field Points All facet polygons, concatenated in facet order.
   type Voronoi_Diagram (Facet_Count, Point_Count : Natural) is record
      Facets : Voronoi_Facet_Array (1 .. Facet_Count);
      Points : Float32_Point_Array (1 .. Point_Count);
   end record;

   --  The polygon of Diagram.Facets (Index), indexed 1 .. N. Raises
   --  Constraint_Error when Index or that facet's slice lies outside Diagram.
   --  @param Diagram A Voronoi diagram, normally from Voronoi_Facets.
   --  @param Index A facet index in 1 .. Diagram.Facet_Count.
   --  @return A copy of that facet's polygon, indexed 1 .. N.
   --  @exception Constraint_Error Index outside Diagram.Facets, or a facet
   --    slice outside Diagram.Points (only in a diagram not built by
   --    Voronoi_Facets).
   function Facet_Points
     (Diagram : Voronoi_Diagram; Index : Positive) return Float32_Point_Array;

   --  The facet of every inserted point, once each and in increasing Site
   --  order, as by cv::Subdiv2D::getVoronoiFacetList for every vertex. An
   --  object without inserted points gives an empty diagram.
   --  @param Object A ready subdivision; its Voronoi data may be recomputed.
   --  @return The diagram of every inserted point's facet.
   --  @exception OpenCV_Error An Object that is not ready, an inconsistent
   --    native result, or another native failure; Object stays ready after
   --    a native failure.
   function Voronoi_Facets
     (Object : in out Subdivision) return Voronoi_Diagram;

   --  The facets of Sites, in order and once per occurrence, as by
   --  getVoronoiFacetList with Sites as its index list. Each element must be
   --  the vertex of an inserted point. No_Vertex, the super-triangle
   --  vertices 1 .. 3, free slots, Voronoi vertices, and identifiers beyond
   --  native storage raise OpenCV.OpenCV_Error. Unlike OpenCV, which treats
   --  an empty index list as every vertex, empty Sites give an empty
   --  diagram.
   --  @param Object A ready subdivision; its Voronoi data may be recomputed.
   --  @param Sites Vertices of inserted points, with any bounds; may repeat.
   --  @return The facets of Sites in order, one per element.
   --  @exception OpenCV_Error A Sites element that is not an inserted point's
   --    vertex (checked before any native computation), an Object that is
   --    not ready, an inconsistent native result, or another native failure;
   --    Object stays ready after a native failure.
   function Voronoi_Facets
     (Object : in out Subdivision; Sites : Vertex_Id_Array)
      return Voronoi_Diagram;

private

   type Bounds_Representation is (No_Bounds, Integer_Bounds, Float32_Bounds);

   type Subdivision is new Ada.Finalization.Limited_Controlled with record
      Handle        : Internal.C_API.Subdiv2D_Handle := null;
      Bounds        : OpenCV.Rect := (X => 0, Y => 0, Width => 0, Height => 0);
      Native_Bounds : Float32_Rectangle;
      Bounds_Mode   : Bounds_Representation := No_Bounds;
   end record;

   --  Releases the native subdivision exactly once; finalizing an object
   --  that owns none, or finalizing again, does nothing.
   --  @param Object The subdivision whose native object is released.
   overriding
   procedure Finalize (Object : in out Subdivision);

end OpenCV.Geometry.Subdiv2D;
