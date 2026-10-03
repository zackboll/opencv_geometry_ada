with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;
with OpenCV.Geometry.Subdiv2D;

package body Subdiv2D_Navigation_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Subdiv renames OpenCV.Geometry.Subdiv2D;

   use type C_API.Status;
   use type Interfaces.C.C_float;
   use type Interfaces.Integer_32;
   use type OpenCV.Float32_Point;
   use type OpenCV.Float32_Value;
   use type OpenCV.Geometry.Float32_Point_Array;
   use type OpenCV.Point_Coordinate;
   use type Subdiv.Edge_Id;
   use type Subdiv.Edge_Segment_Array;
   use type Subdiv.Vertex_Id;

   subtype Points is OpenCV.Geometry.Float32_Point_Array;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Square : constant OpenCV.Rect :=
     (X => 0, Y => 0, Width => 100, Height => 100);

   --  Three hull points around one interior point: its Delaunay
   --  triangulation is unique and has the six edges listed below.
   Fixture_Points : constant Points :=
     ((X => 10.0, Y => 10.0),
      (X => 90.0, Y => 10.0),
      (X => 50.0, Y => 80.0),
      (X => 50.0, Y => 40.0));

   type Point_Pair is record
      First, Second : OpenCV.Float32_Point;
   end record;

   Fixture_Edges : constant array (1 .. 6) of Point_Pair :=
     ((Fixture_Points (0), Fixture_Points (1)),
      (Fixture_Points (1), Fixture_Points (2)),
      (Fixture_Points (2), Fixture_Points (0)),
      (Fixture_Points (0), Fixture_Points (3)),
      (Fixture_Points (1), Fixture_Points (3)),
      (Fixture_Points (2), Fixture_Points (3)));

   procedure Assert_Raises_OpenCV_Error
     (Attempt : not null access procedure; Message : String)
   is
      Raised : Boolean := False;
   begin
      begin
         Attempt.all;
      exception
         when OpenCV.OpenCV_Error =>
            Raised := True;
      end;

      AUnit.Assertions.Assert (Raised, Message);
   end Assert_Raises_OpenCV_Error;

   function Is_Fixture_Point (Point : OpenCV.Float32_Point) return Boolean is
   begin
      for Candidate of Fixture_Points loop
         if Candidate = Point then
            return True;
         end if;
      end loop;
      return False;
   end Is_Fixture_Point;

   function Inside_Square (Point : OpenCV.Float32_Point) return Boolean
   is (Point.X >= 0.0
       and then Point.X < 100.0
       and then Point.Y >= 0.0
       and then Point.Y < 100.0);

   function Same_Undirected
     (Segment : Subdiv.Edge_Segment; Pair : Point_Pair) return Boolean
   is ((Segment.Origin = Pair.First and then Segment.Destination = Pair.Second)
       or else (Segment.Origin = Pair.Second
                and then Segment.Destination = Pair.First));

   --  The rotation selecting quad-edge member Offset (0 .. 3).
   function Rotation_For (Offset : Natural) return Subdiv.Edge_Rotation
   is (Subdiv.Edge_Rotation'Val (Offset));

   --  A subdivision holding the fixture.
   function Fixture_Subdivision return Subdiv.Subdivision is
   begin
      return Object : Subdiv.Subdivision := Subdiv.Create (Square) do
         Subdiv.Insert (Object, Fixture_Points);
      end return;
   end Fixture_Subdivision;

   --  True when the leading edges form closed three-edge left facets whose
   --  consecutive edges share endpoints.
   function Facets_Are_Triangles (Object : Subdiv.Subdivision) return Boolean
   is
   begin
      for Edge of Subdiv.Leading_Edge_List (Object) loop
         declare
            Second : constant Subdiv.Edge_Id :=
              Subdiv.Navigate (Object, Edge, Subdiv.Next_Around_Left);
            Third  : constant Subdiv.Edge_Id :=
              Subdiv.Navigate (Object, Second, Subdiv.Next_Around_Left);
         begin
            if Subdiv.Navigate (Object, Third, Subdiv.Next_Around_Left) /= Edge
              or else Subdiv.Origin (Object, Second)
                      /= Subdiv.Destination (Object, Edge)
              or else Subdiv.Origin (Object, Third)
                      /= Subdiv.Destination (Object, Second)
            then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Facets_Are_Triangles;

   procedure Empty_Subdivision (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : constant Subdiv.Subdivision := Subdiv.Create (Square);
   begin
      AUnit.Assertions.Assert
        (Subdiv.Edge_List (Object)'Length = 0,
         "an empty subdivision has no Delaunay edges outside the "
         & "super-triangle");
      AUnit.Assertions.Assert
        (Subdiv.Triangle_List (Object)'Length = 0,
         "an empty subdivision has no triangles inside the bounds");
      AUnit.Assertions.Assert
        (Subdiv.Leading_Edge_List (Object)'Length > 0
         and then Facets_Are_Triangles (Object),
         "the super-triangle's facets are triangles");
   end Empty_Subdivision;

   procedure Edge_List_Contents (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : constant Subdiv.Subdivision := Fixture_Subdivision;
      Edges  : constant Subdiv.Edge_Segment_Array := Subdiv.Edge_List (Object);
   begin
      AUnit.Assertions.Assert
        (Edges'First = 1, "results are indexed from one");
      for Pair of Fixture_Edges loop
         declare
            Found : Boolean := False;
         begin
            for Segment of Edges loop
               Found := Found or else Same_Undirected (Segment, Pair);
            end loop;
            AUnit.Assertions.Assert
              (Found, "every Delaunay edge of the fixture is listed");
         end;
      end loop;
      for Segment of Edges loop
         AUnit.Assertions.Assert
           ((Is_Fixture_Point (Segment.Origin)
             or else not Inside_Square (Segment.Origin))
            and then (Is_Fixture_Point (Segment.Destination)
                      or else not Inside_Square (Segment.Destination))
            and then Segment.Origin /= Segment.Destination,
            "every edge joins inserted points or super-triangle vertices");
      end loop;
   end Edge_List_Contents;

   procedure Triangle_List_Contents (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object    : constant Subdiv.Subdivision := Fixture_Subdivision;
      Triangles : constant Subdiv.Triangle_Array :=
        Subdiv.Triangle_List (Object);
      --  The triangle containing (50, 20) is determined by the unique
      --  Delaunay triangulation and lies inside the bounds.
      Found     : Boolean := False;
   begin
      AUnit.Assertions.Assert
        (Triangles'Length > 0, "the fixture has triangles");
      for Triangle of Triangles loop
         for Corner of Triangle loop
            AUnit.Assertions.Assert
              (Is_Fixture_Point (Corner) and then Inside_Square (Corner),
               "triangle vertices are inserted points inside the bounds");
         end loop;
         AUnit.Assertions.Assert
           (Triangle (1) /= Triangle (2)
            and then Triangle (2) /= Triangle (3)
            and then Triangle (1) /= Triangle (3),
            "triangle vertices are distinct");
         Found :=
           Found
           or else (for all Corner of Triangle =>
                      Corner = Fixture_Points (0)
                      or else Corner = Fixture_Points (1)
                      or else Corner = Fixture_Points (3));
      end loop;
      AUnit.Assertions.Assert
        (Found, "the triangle containing an interior point is listed");
   end Triangle_List_Contents;

   procedure Vertices_Match_Insertions (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
   begin
      for Point of Fixture_Points loop
         declare
            Vertex : constant Subdiv.Vertex_Id :=
              Subdiv.Insert (Object, Point);
         begin
            AUnit.Assertions.Assert
              (Subdiv.Vertex_Point (Object, Vertex) = Point,
               "Vertex_Point reports the inserted position");
            AUnit.Assertions.Assert
              (Subdiv.Origin (Object, Subdiv.First_Edge (Object, Vertex))
               = Vertex,
               "a vertex's first edge starts at the vertex");
         end;
      end loop;
      for Super_Vertex in Subdiv.Vertex_Id range 1 .. 3 loop
         AUnit.Assertions.Assert
           (not Inside_Square (Subdiv.Vertex_Point (Object, Super_Vertex)),
            "super-triangle vertices lie outside the bounds");
      end loop;
   end Vertices_Match_Insertions;

   procedure Endpoints_And_Reversal (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : constant Subdiv.Subdivision := Fixture_Subdivision;
   begin
      for Edge of Subdiv.Leading_Edge_List (Object) loop
         declare
            Reversed : constant Subdiv.Edge_Id :=
              Subdiv.Symmetric_Edge (Object, Edge);
         begin
            AUnit.Assertions.Assert
              (Subdiv.Origin (Object, Reversed)
               = Subdiv.Destination (Object, Edge)
               and then Subdiv.Destination (Object, Reversed)
                        = Subdiv.Origin (Object, Edge),
               "Symmetric_Edge swaps origin and destination");
            AUnit.Assertions.Assert
              (Subdiv.Origin (Object, Edge) /= Subdiv.No_Vertex
               and then Subdiv.Origin (Object, Edge)
                        /= Subdiv.Destination (Object, Edge),
               "a Delaunay edge joins two distinct vertices");
            AUnit.Assertions.Assert
              (Subdiv.Symmetric_Edge (Object, Reversed) = Edge,
               "reversing twice returns the edge");
         end;
      end loop;
   end Endpoints_And_Reversal;

   procedure Rotation_Invariants (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : constant Subdiv.Subdivision := Fixture_Subdivision;
   begin
      for Edge of Subdiv.Leading_Edge_List (Object) loop
         declare
            Turned : Subdiv.Edge_Id := Edge;
         begin
            for Step in 1 .. 4 loop
               Turned := Subdiv.Rotate (Object, Turned, Subdiv.Rotated_Edge);
               AUnit.Assertions.Assert
                 ((Step = 4) = (Turned = Edge),
                  "four rotations, and no fewer, return the edge");
            end loop;
            AUnit.Assertions.Assert
              (Subdiv.Rotate (Object, Edge, Subdiv.Same_Edge) = Edge
               and then Subdiv.Rotate (Object, Edge, Subdiv.Reversed_Edge)
                        = Subdiv.Symmetric_Edge (Object, Edge)
               and then Subdiv.Rotate
                          (Object, Edge, Subdiv.Reversed_Rotated_Edge)
                        = Subdiv.Rotate
                            (Object,
                             Subdiv.Rotate (Object, Edge, Subdiv.Rotated_Edge),
                             Subdiv.Reversed_Edge),
               "rotation choices compose as quad-edge rotations");
         end;
      end loop;
   end Rotation_Invariants;

   procedure Navigation_Identities (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : constant Subdiv.Subdivision := Fixture_Subdivision;

      function Go
        (Edge : Subdiv.Edge_Id; Direction : Subdiv.Edge_Navigation)
         return Subdiv.Edge_Id
      is (Subdiv.Navigate (Object, Edge, Direction));

      function Org (Edge : Subdiv.Edge_Id) return Subdiv.Vertex_Id
      is (Subdiv.Origin (Object, Edge));

      function Dst (Edge : Subdiv.Edge_Id) return Subdiv.Vertex_Id
      is (Subdiv.Destination (Object, Edge));
   begin
      for Direction in Subdiv.Edge_Navigation loop
         for Edge of Subdiv.Leading_Edge_List (Object) loop
            declare
               Related : constant Subdiv.Edge_Id := Go (Edge, Direction);
            begin
               case Direction is
                  when Subdiv.Next_Around_Origin
                     | Subdiv.Previous_Around_Origin
                  =>
                     AUnit.Assertions.Assert
                       (Org (Related) = Org (Edge),
                        Direction'Image & " shares the origin");

                  when Subdiv.Next_Around_Destination
                     | Subdiv.Previous_Around_Destination
                  =>
                     AUnit.Assertions.Assert
                       (Dst (Related) = Dst (Edge),
                        Direction'Image & " shares the destination");

                  when Subdiv.Next_Around_Left | Subdiv.Previous_Around_Right
                  =>
                     AUnit.Assertions.Assert
                       (Org (Related) = Dst (Edge),
                        Direction'Image & " starts at the destination");

                  when Subdiv.Next_Around_Right | Subdiv.Previous_Around_Left
                  =>
                     AUnit.Assertions.Assert
                       (Dst (Related) = Org (Edge),
                        Direction'Image & " ends at the origin");
               end case;
            end;
         end loop;
      end loop;

      for Edge of Subdiv.Leading_Edge_List (Object) loop
         AUnit.Assertions.Assert
           (Go
              (Go (Edge, Subdiv.Next_Around_Origin),
               Subdiv.Previous_Around_Origin)
            = Edge
            and then Go
                       (Go (Edge, Subdiv.Next_Around_Destination),
                        Subdiv.Previous_Around_Destination)
                     = Edge
            and then Go
                       (Go (Edge, Subdiv.Next_Around_Left),
                        Subdiv.Previous_Around_Left)
                     = Edge
            and then Go
                       (Go (Edge, Subdiv.Next_Around_Right),
                        Subdiv.Previous_Around_Right)
                     = Edge,
            "each Next choice is undone by its Previous choice");
         AUnit.Assertions.Assert
           (Subdiv.Next_Edge (Object, Edge)
            = Go (Edge, Subdiv.Next_Around_Origin),
            "Next_Edge is Next_Around_Origin");
      end loop;
      AUnit.Assertions.Assert
        (Facets_Are_Triangles (Object), "every facet is a triangle");
   end Navigation_Identities;

   procedure Navigation_Encoding (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : constant Subdiv.Subdivision := Fixture_Subdivision;

      --  OpenCV encodes each getEdge choice as rotations A (low bits) and B
      --  (bits 4 .. 5): getEdge (E, T) = rotateEdge (nextEdge (rotateEdge
      --  (E, A)), B), with NEXT_AROUND_ORG = 16#00#, NEXT_AROUND_DST = 16#22#,
      --  PREV_AROUND_ORG = 16#11#, PREV_AROUND_DST = 16#33#,
      --  NEXT_AROUND_LEFT = 16#13#, NEXT_AROUND_RIGHT = 16#31#,
      --  PREV_AROUND_LEFT = 16#20#, and PREV_AROUND_RIGHT = 16#02#.
      type Encoding is record
         Before, After : Natural;
      end record;

      Encodings : constant array (Subdiv.Edge_Navigation) of Encoding :=
        (Subdiv.Next_Around_Origin          => (0, 0),
         Subdiv.Next_Around_Destination     => (2, 2),
         Subdiv.Previous_Around_Origin      => (1, 1),
         Subdiv.Previous_Around_Destination => (3, 3),
         Subdiv.Next_Around_Left            => (3, 1),
         Subdiv.Next_Around_Right           => (1, 3),
         Subdiv.Previous_Around_Left        => (0, 2),
         Subdiv.Previous_Around_Right       => (2, 0));
   begin
      for Direction in Subdiv.Edge_Navigation loop
         for Edge of Subdiv.Leading_Edge_List (Object) loop
            declare
               Code     : constant Encoding := Encodings (Direction);
               Expected : constant Subdiv.Edge_Id :=
                 Subdiv.Rotate
                   (Object,
                    Subdiv.Next_Edge
                      (Object,
                       Subdiv.Rotate
                         (Object, Edge, Rotation_For (Code.Before))),
                    Rotation_For (Code.After));
            begin
               AUnit.Assertions.Assert
                 (Subdiv.Navigate (Object, Edge, Direction) = Expected,
                  Direction'Image & " follows OpenCV's getEdge encoding");
            end;
         end loop;
      end loop;
   end Navigation_Encoding;

   procedure Voronoi_Dual_Edges (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Object   : Subdiv.Subdivision := Fixture_Subdivision;
      Interior : Subdiv.Edge_Id := Subdiv.No_Edge;
      Outer    : Subdiv.Edge_Id := Subdiv.No_Edge;

      type Vertex_Pair is array (1 .. 2) of Subdiv.Vertex_Id;

      function Distance_Squared (A, B : OpenCV.Float32_Point) return Float
      is ((Float (A.X) - Float (B.X))**2 + (Float (A.Y) - Float (B.Y))**2);

      --  True when Center is equidistant from the three vertices of the
      --  facet on the left of Edge, so it is that facet's circumcenter.
      function Circumcenter_Of_Left_Facet
        (Center : Subdiv.Vertex_Id; Edge : Subdiv.Edge_Id) return Boolean
      is
         Position : constant OpenCV.Float32_Point :=
           Subdiv.Vertex_Point (Object, Center);
         Next     : constant Subdiv.Edge_Id :=
           Subdiv.Navigate (Object, Edge, Subdiv.Next_Around_Left);
         Radius   : constant Float :=
           Distance_Squared
             (Position,
              Subdiv.Vertex_Point (Object, Subdiv.Origin (Object, Edge)));
      begin
         for Corner of
           Vertex_Pair'
             (Subdiv.Destination (Object, Edge),
              Subdiv.Destination (Object, Next))
         loop
            if abs (Distance_Squared
                      (Position, Subdiv.Vertex_Point (Object, Corner))
                    - Radius)
              > 1.0E-3 * Float'Max (Radius, 1.0)
            then
               return False;
            end if;
         end loop;
         return True;
      end Circumcenter_Of_Left_Facet;
   begin
      --  Pick a Delaunay edge between inserted points, and an edge whose left
      --  facet is the facet outside the super-triangle: once points are
      --  inserted, no other facet has only super-triangle vertices.
      for Edge of Subdiv.Leading_Edge_List (Object) loop
         declare
            Second : constant Subdiv.Edge_Id :=
              Subdiv.Navigate (Object, Edge, Subdiv.Next_Around_Left);
            Third  : constant Subdiv.Edge_Id :=
              Subdiv.Navigate (Object, Second, Subdiv.Next_Around_Left);
         begin
            if Subdiv.Origin (Object, Edge) > 3
              and then Subdiv.Destination (Object, Edge) > 3
            then
               Interior := Edge;
            elsif Subdiv.Origin (Object, Edge) <= 3
              and then Subdiv.Origin (Object, Second) <= 3
              and then Subdiv.Origin (Object, Third) <= 3
            then
               Outer := Edge;
            end if;
         end;
      end loop;
      AUnit.Assertions.Assert
        (Interior /= Subdiv.No_Edge and then Outer /= Subdiv.No_Edge,
         "the fixture has an interior edge and an outer facet");

      declare
         Dual       : constant Subdiv.Edge_Id :=
           Subdiv.Rotate (Object, Interior, Subdiv.Rotated_Edge);
         Outer_Dual : constant Subdiv.Edge_Id :=
           Subdiv.Rotate (Object, Outer, Subdiv.Rotated_Edge);
      begin
         AUnit.Assertions.Assert
           (Subdiv.Origin (Object, Dual) = Subdiv.No_Vertex
            and then Subdiv.Destination (Object, Dual) = Subdiv.No_Vertex
            and then Subdiv.Origin (Object, Outer_Dual) = Subdiv.No_Vertex,
            "dual edges have no Voronoi vertices before Voronoi computation");
         declare
            Ignored : constant Subdiv.Nearest_Result :=
              Subdiv.Find_Nearest (Object, (X => 50.0, Y => 50.0));
         begin
            null;
         end;
         AUnit.Assertions.Assert
           (Subdiv.Origin (Object, Dual) /= Subdiv.No_Vertex
            and then Subdiv.Destination (Object, Dual) /= Subdiv.No_Vertex,
            "Find_Nearest computes the dual edge's Voronoi vertices");
         AUnit.Assertions.Assert
           (Subdiv.Destination (Object, Outer_Dual) = Subdiv.No_Vertex,
            "the facet outside the super-triangle has no Voronoi vertex");
         AUnit.Assertions.Assert
           (Subdiv.Origin (Object, Outer_Dual) /= Subdiv.No_Vertex
            and then Circumcenter_Of_Left_Facet
                       (Subdiv.Origin (Object, Outer_Dual),
                        Subdiv.Symmetric_Edge (Object, Outer)),
            "the inner end of a super-triangle edge's dual is computed");
         AUnit.Assertions.Assert
           (Subdiv.First_Edge (Object, Subdiv.Origin (Object, Dual))
            = Subdiv.No_Edge,
            "a Voronoi vertex records no first edge");

         --  The dual runs from the circumcenter of the facet on the primal
         --  edge's right to that of the facet on its left.
         AUnit.Assertions.Assert
           (Circumcenter_Of_Left_Facet
              (Subdiv.Destination (Object, Dual), Interior),
            "a dual edge ends at its primal edge's left facet");
         AUnit.Assertions.Assert
           (Circumcenter_Of_Left_Facet
              (Subdiv.Origin (Object, Dual),
               Subdiv.Symmetric_Edge (Object, Interior)),
            "a dual edge starts at its primal edge's right facet");
      end;
   end Voronoi_Dual_Edges;

   procedure Results_Survive_Mutation (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object    : Subdiv.Subdivision := Fixture_Subdivision;
      Edges     : constant Subdiv.Edge_Segment_Array :=
        Subdiv.Edge_List (Object);
      Copy      : constant Subdiv.Edge_Segment_Array := Edges;
      Triangles : constant Natural := Subdiv.Triangle_List (Object)'Length;
   begin
      Subdiv.Insert
        (Object,
         Points'
           ((X => 30.0, Y => 30.0),
            (X => 70.0, Y => 30.0),
            (X => 50.0, Y => 60.0),
            (X => 20.0, Y => 50.0)));
      AUnit.Assertions.Assert
        (Edges = Copy, "an earlier result is unchanged by later insertions");
      AUnit.Assertions.Assert
        (Subdiv.Triangle_List (Object)'Length > Triangles
         and then Subdiv.Edge_List (Object)'Length > Edges'Length,
         "insertions add triangles and edges");
      AUnit.Assertions.Assert
        (Facets_Are_Triangles (Object),
         "every facet stays a triangle after insertions");
      Subdiv.Reset (Object, Square);
      AUnit.Assertions.Assert
        (Edges = Copy and then Subdiv.Edge_List (Object)'Length = 0,
         "Reset does not affect earlier results");
   end Results_Survive_Mutation;

   procedure Translated_Bounds_And_Shifted_Arrays (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object  : Subdiv.Subdivision :=
        Subdiv.Create
          (OpenCV.Rect'(X => -50, Y => -20, Width => 10, Height => 10));
      Shifted : constant Points (10 .. 12) :=
        ((X => -48.0, Y => -18.0),
         (X => -42.0, Y => -17.0),
         (X => -45.0, Y => -12.0));
   begin
      Subdiv.Insert (Object, Shifted);
      for Triangle of Subdiv.Triangle_List (Object) loop
         for Corner of Triangle loop
            AUnit.Assertions.Assert
              (Corner = Shifted (10)
               or else Corner = Shifted (11)
               or else Corner = Shifted (12),
               "triangles of a translated subdivision use its points");
         end loop;
      end loop;
      for Segment of Subdiv.Edge_List (Object) loop
         AUnit.Assertions.Assert
           (Segment.Origin /= Segment.Destination,
            "edges of a translated subdivision are proper");
      end loop;
      AUnit.Assertions.Assert
        (Facets_Are_Triangles (Object),
         "facets of a translated subdivision are triangles");
   end Translated_Bounds_And_Shifted_Arrays;

   procedure Rejects_Invalid_Identifiers (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Object  : constant Subdiv.Subdivision := Fixture_Subdivision;
      Unready : Subdiv.Subdivision;
      Leading : constant Subdiv.Edge_Id :=
        Subdiv.Leading_Edge_List (Object) (1);

      procedure Origin_Of_No_Edge is
         Ignored : constant Subdiv.Vertex_Id :=
           Subdiv.Origin (Object, Subdiv.No_Edge);
      begin
         null;
      end Origin_Of_No_Edge;

      procedure Origin_Of_Null_Edge_Rotation is
         Ignored : constant Subdiv.Vertex_Id := Subdiv.Origin (Object, 3);
      begin
         null;
      end Origin_Of_Null_Edge_Rotation;

      procedure Destination_Beyond_Storage is
         Ignored : constant Subdiv.Vertex_Id :=
           Subdiv.Destination (Object, Subdiv.Edge_Id'Last);
      begin
         null;
      end Destination_Beyond_Storage;

      procedure Navigate_Beyond_Storage is
         Ignored : constant Subdiv.Edge_Id :=
           Subdiv.Navigate (Object, 1_000_000, Subdiv.Next_Around_Left);
      begin
         null;
      end Navigate_Beyond_Storage;

      procedure Rotate_No_Edge is
         Ignored : constant Subdiv.Edge_Id :=
           Subdiv.Rotate (Object, Subdiv.No_Edge, Subdiv.Rotated_Edge);
      begin
         null;
      end Rotate_No_Edge;

      procedure Next_Beyond_Storage is
         Ignored : constant Subdiv.Edge_Id :=
           Subdiv.Next_Edge (Object, 400_000);
      begin
         null;
      end Next_Beyond_Storage;

      procedure Symmetric_No_Edge is
         Ignored : constant Subdiv.Edge_Id :=
           Subdiv.Symmetric_Edge (Object, Subdiv.No_Edge);
      begin
         null;
      end Symmetric_No_Edge;

      procedure Point_Of_No_Vertex is
         Ignored : constant OpenCV.Float32_Point :=
           Subdiv.Vertex_Point (Object, Subdiv.No_Vertex);
      begin
         null;
      end Point_Of_No_Vertex;

      procedure Point_Beyond_Storage is
         Ignored : constant OpenCV.Float32_Point :=
           Subdiv.Vertex_Point (Object, Subdiv.Vertex_Id'Last);
      begin
         null;
      end Point_Beyond_Storage;

      procedure First_Edge_Of_No_Vertex is
         Ignored : constant Subdiv.Edge_Id :=
           Subdiv.First_Edge (Object, Subdiv.No_Vertex);
      begin
         null;
      end First_Edge_Of_No_Vertex;

      procedure List_Of_Unready is
         Ignored : constant Subdiv.Edge_Segment_Array :=
           Subdiv.Edge_List (Unready);
      begin
         null;
      end List_Of_Unready;

      procedure Navigate_Unready is
         Ignored : constant Subdiv.Edge_Id :=
           Subdiv.Navigate (Unready, Leading, Subdiv.Next_Around_Left);
      begin
         null;
      end Navigate_Unready;
   begin
      Assert_Raises_OpenCV_Error
        (Origin_Of_No_Edge'Access, "No_Edge is rejected");
      Assert_Raises_OpenCV_Error
        (Origin_Of_Null_Edge_Rotation'Access,
         "identifiers of the null edge are rejected");
      Assert_Raises_OpenCV_Error
        (Destination_Beyond_Storage'Access,
         "an edge beyond native storage is rejected");
      Assert_Raises_OpenCV_Error
        (Navigate_Beyond_Storage'Access,
         "Navigate rejects an edge beyond native storage");
      Assert_Raises_OpenCV_Error
        (Rotate_No_Edge'Access, "Rotate rejects No_Edge");
      Assert_Raises_OpenCV_Error
        (Next_Beyond_Storage'Access,
         "Next_Edge rejects an edge beyond native storage");
      Assert_Raises_OpenCV_Error
        (Symmetric_No_Edge'Access, "Symmetric_Edge rejects No_Edge");
      Assert_Raises_OpenCV_Error
        (Point_Of_No_Vertex'Access, "No_Vertex is rejected");
      Assert_Raises_OpenCV_Error
        (Point_Beyond_Storage'Access,
         "a vertex beyond native storage is rejected");
      Assert_Raises_OpenCV_Error
        (First_Edge_Of_No_Vertex'Access, "First_Edge rejects No_Vertex");
      Assert_Raises_OpenCV_Error
        (List_Of_Unready'Access, "lists require a ready subdivision");
      Assert_Raises_OpenCV_Error
        (Navigate_Unready'Access, "navigation requires a ready subdivision");
      AUnit.Assertions.Assert
        (Subdiv.Is_Ready (Object),
         "rejected identifiers leave the subdivision ready");
   end Rejects_Invalid_Identifiers;

   --  The Ada lists preserve the native lists element for element and in
   --  order. OpenCV is deterministic, so a raw handle and a Subdivision given
   --  the same points hold the same triangulation.
   procedure Lists_Preserve_Native_Order (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Sources   : constant Points :=
        Fixture_Points
        & Points'
            ((X => 30.0, Y => 20.0),
             (X => 70.0, Y => 30.0),
             (X => 20.0, Y => 60.0),
             (X => 80.0, Y => 70.0),
             (X => 50.0, Y => 60.0));
      Bounds    : aliased constant C_API.Rect_I32 :=
        (X => 0, Y => 0, Width => 100, Height => 100);
      Handle    : aliased C_API.Subdiv2D_Handle := null;
      Batch     : aliased C_API.Point_F32_Array (0 .. Sources'Length - 1);
      Segments  : aliased C_API.C_Edge_Segment_Array (0 .. 199);
      Leading   : aliased C_API.Int32_Array (0 .. 399);
      Triangles : aliased C_API.C_Triangle_Array (0 .. 399);
      Count     : aliased Interfaces.Integer_32 := 0;
      Status    : C_API.Status;
      Object    : Subdiv.Subdivision := Subdiv.Create (Square);

      function To_Point
        (X, Y : Interfaces.C.C_float) return OpenCV.Float32_Point
      is (X => OpenCV.Float32_Value (X), Y => OpenCV.Float32_Value (Y));
   begin
      for Offset in Batch'Range loop
         Batch (Offset) :=
           (X => Interfaces.C.C_float (Sources (Sources'First + Offset).X),
            Y => Interfaces.C.C_float (Sources (Sources'First + Offset).Y));
      end loop;
      Status := C_API.Subdiv2D_Create (Bounds'Access, Handle'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "a raw subdivision is created");
      Status :=
        C_API.Subdiv2D_Insert_Points
          (Handle, Batch (0)'Access, Batch'Length, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = Batch'Length,
         "the raw points are inserted");
      Subdiv.Insert (Object, Sources);

      Status :=
        C_API.Subdiv2D_Get_Edge_List
          (Handle, Segments (0)'Access, Segments'Length, Count'Access);
      declare
         Edges : constant Subdiv.Edge_Segment_Array :=
           Subdiv.Edge_List (Object);
      begin
         AUnit.Assertions.Assert
           (Status = C_API.Success
            and then Edges'First = 1
            and then Edges'Length = Natural (Count),
            "the edge list has the native length, indexed from one");
         for Index in Edges'Range loop
            AUnit.Assertions.Assert
              (Edges (Index).Origin
               = To_Point
                   (Segments (Index - 1).Origin_X,
                    Segments (Index - 1).Origin_Y)
               and then Edges (Index).Destination
                        = To_Point
                            (Segments (Index - 1).Destination_X,
                             Segments (Index - 1).Destination_Y),
               "each edge preserves the native edge in order");
         end loop;
      end;

      Status :=
        C_API.Subdiv2D_Get_Leading_Edge_List
          (Handle, Leading (0)'Access, Leading'Length, Count'Access);
      declare
         Edges : constant Subdiv.Edge_Id_Array :=
           Subdiv.Leading_Edge_List (Object);
      begin
         AUnit.Assertions.Assert
           (Status = C_API.Success
            and then Edges'First = 1
            and then Edges'Length = Natural (Count),
            "the leading edge list has the native length, indexed from one");
         for Index in Edges'Range loop
            AUnit.Assertions.Assert
              (Interfaces.Integer_32 (Edges (Index)) = Leading (Index - 1),
               "each leading edge preserves the native edge in order");
         end loop;
      end;

      Status :=
        C_API.Subdiv2D_Get_Triangle_List
          (Handle, Triangles (0)'Access, Triangles'Length, Count'Access);
      declare
         List : constant Subdiv.Triangle_Array :=
           Subdiv.Triangle_List (Object);
      begin
         AUnit.Assertions.Assert
           (Status = C_API.Success
            and then List'First = 1
            and then List'Length = Natural (Count),
            "the triangle list has the native length, indexed from one");
         for Index in List'Range loop
            declare
               Raw : constant C_API.C_Triangle := Triangles (Index - 1);
            begin
               AUnit.Assertions.Assert
                 (List (Index) (1) = To_Point (Raw.V0_X, Raw.V0_Y)
                  and then List (Index) (2) = To_Point (Raw.V1_X, Raw.V1_Y)
                  and then List (Index) (3) = To_Point (Raw.V2_X, Raw.V2_Y),
                  "each triangle preserves the native triangle in order");
            end;
         end loop;
      end;

      C_API.Subdiv2D_Destroy (Handle);
   exception
      when others =>
         C_API.Subdiv2D_Destroy (Handle);
         raise;
   end Lists_Preserve_Native_Order;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);

      type Selector_List is array (Positive range <>) of Interfaces.Integer_32;

      Bounds    : aliased constant C_API.Rect_I32 :=
        (X => 0, Y => 0, Width => 100, Height => 100);
      Handle    : aliased C_API.Subdiv2D_Handle := null;
      Batch     : aliased C_API.Point_F32_Array (0 .. 3) :=
        ((X => 10.0, Y => 10.0),
         (X => 90.0, Y => 10.0),
         (X => 50.0, Y => 80.0),
         (X => 50.0, Y => 40.0));
      Count     : aliased Interfaces.Integer_32 := 0;
      Value     : aliased Interfaces.Integer_32 := 0;
      Kind      : aliased Interfaces.Integer_32 := 0;
      Position  : aliased C_API.Point_F32 := (X => 7.0, Y => 7.0);
      Segments  : aliased C_API.C_Edge_Segment_Array (0 .. 99);
      Leading   : aliased C_API.Int32_Array (0 .. 199);
      Triangles : aliased C_API.C_Triangle_Array (0 .. 199);
      Status    : C_API.Status;
      Quads     : Interfaces.Integer_32;
   begin
      Status := C_API.Subdiv2D_Create (Bounds'Access, Handle'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "a raw subdivision is created");
      Status :=
        C_API.Subdiv2D_Insert_Points
          (Handle, Batch (0)'Access, 4, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count = 4,
         "the raw fixture is inserted");

      Status := C_API.Subdiv2D_Quad_Edge_Count (Handle, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "quad_edge_count rejects a null output");
      Count := 99;
      Status := C_API.Subdiv2D_Quad_Edge_Count (null, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Count = 0,
         "quad_edge_count rejects a null handle");
      Status := C_API.Subdiv2D_Quad_Edge_Count (Handle, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count > 4,
         "quad_edge_count reports native slots");
      Quads := Count;

      --  List argument validation.
      Count := 99;
      Status :=
        C_API.Subdiv2D_Get_Edge_List
          (Handle, Segments (0)'Access, -1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Count = 0,
         "a negative list capacity is rejected");
      Status := C_API.Subdiv2D_Get_Edge_List (Handle, null, 5, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "a null list buffer with positive capacity is rejected");
      Status :=
        C_API.Subdiv2D_Get_Edge_List (Handle, Segments (0)'Access, 100, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "a null list count output is rejected");
      Count := 99;
      Status :=
        C_API.Subdiv2D_Get_Edge_List
          (null, Segments (0)'Access, 100, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Count = 0,
         "list functions reject a null handle");
      Count := 99;
      Status :=
        C_API.Subdiv2D_Get_Edge_List
          (Handle, Segments (0)'Access, 1, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Count = 0
         and then C_API.Last_Error_Message'Length > 0,
         "an insufficient capacity publishes nothing");
      Status :=
        C_API.Subdiv2D_Get_Edge_List
          (Handle, Segments (0)'Access, 100, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Count > 0 and then Count <= Quads - 4,
         "the edge list fits its capacity bound");
      Status :=
        C_API.Subdiv2D_Get_Leading_Edge_List
          (Handle, Leading (0)'Access, 200, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Count > 0
         and then Count <= 2 * Quads - 2,
         "the leading edge list fits its capacity bound");
      Status :=
        C_API.Subdiv2D_Get_Triangle_List
          (Handle, Triangles (0)'Access, 200, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Count > 0
         and then Count <= 2 * Quads - 2,
         "the triangle list fits its capacity bound");
      Status :=
        C_API.Subdiv2D_Get_Triangle_List (Handle, null, 0, Count'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Count = 0,
         "a zero capacity cannot hold a non-empty triangle list");

      --  Identifier ranges are enforced before OpenCV sees them.
      Value := 99;
      Status := C_API.Subdiv2D_Edge_Org (Handle, 4 * Quads, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Value = 0,
         "the first edge beyond native storage is rejected");
      Status := C_API.Subdiv2D_Edge_Org (Handle, 4 * Quads - 1, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success,
         "the last edge in native storage is accepted");
      Status := C_API.Subdiv2D_Edge_Dst (Handle, -1, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "a negative edge identifier is rejected");
      Status :=
        C_API.Subdiv2D_Next_Edge
          (Handle, Interfaces.Integer_32'Last, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "the largest edge identifier is rejected");
      Status := C_API.Subdiv2D_Sym_Edge (Handle, 16, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "a null edge output is rejected");
      Status := C_API.Subdiv2D_Sym_Edge (null, 16, Value'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "edge queries reject a null handle");

      for Selector of Selector_List'(-1, 8, 16#13#, 16#22#) loop
         Value := 99;
         Status :=
           C_API.Subdiv2D_Get_Edge (Handle, 16, Selector, Value'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument and then Value = 0,
            "navigation selector" & Selector'Image & " is rejected");
      end loop;
      for Selector of Selector_List'(-1, 4) loop
         Status :=
           C_API.Subdiv2D_Rotate_Edge (Handle, 16, Selector, Value'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument,
            "rotation selector" & Selector'Image & " is rejected");
      end loop;

      Status :=
        C_API.Subdiv2D_Get_Vertex
          (Handle, 1_000_000, Position'Access, Value'Access, Kind'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Position.X = 0.0
         and then Kind = C_API.Subdiv2D_Vertex_Free,
         "a vertex beyond native storage is rejected with safe outputs");
      Status :=
        C_API.Subdiv2D_Get_Vertex
          (Handle, 0, Position'Access, Value'Access, Kind'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Kind = C_API.Subdiv2D_Vertex_Free,
         "the reserved vertex 0 is reported as a free slot");
      Status :=
        C_API.Subdiv2D_Get_Vertex
          (Handle, 4, Position'Access, Value'Access, null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Position.X = 0.0
         and then Value = 0,
         "a null kind output is rejected after zeroing the other outputs");

      C_API.Subdiv2D_Destroy (Handle);
   exception
      when others =>
         C_API.Subdiv2D_Destroy (Handle);
         raise;
   end C_ABI_Validation;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
   begin
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D empty subdivision lists", Empty_Subdivision'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D edge list contents", Edge_List_Contents'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D triangle list contents", Triangle_List_Contents'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D vertices match insertions",
            Vertices_Match_Insertions'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D endpoints and reversal", Endpoints_And_Reversal'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D rotation invariants", Rotation_Invariants'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D navigation identities", Navigation_Identities'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D navigation encoding", Navigation_Encoding'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Voronoi dual edges", Voronoi_Dual_Edges'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D results survive mutation",
            Results_Survive_Mutation'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D translated bounds and shifted arrays",
            Translated_Bounds_And_Shifted_Arrays'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D rejects invalid identifiers",
            Rejects_Invalid_Identifiers'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D lists preserve native order",
            Lists_Preserve_Native_Order'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D navigation C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Subdiv2D_Navigation_Tests;
