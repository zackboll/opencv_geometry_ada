with AUnit.Assertions;
with AUnit.Test_Caller;
with AUnit.Test_Fixtures;
with Interfaces;
with Interfaces.C;
with OpenCV;
with OpenCV.Geometry;
with OpenCV.Geometry.Internal.C_API;
with OpenCV.Geometry.Subdiv2D;

package body Subdiv2D_Voronoi_Tests is

   package C_API renames OpenCV.Geometry.Internal.C_API;
   package Subdiv renames OpenCV.Geometry.Subdiv2D;

   use type C_API.Status;
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_32;
   use type OpenCV.Float32_Point;
   use type OpenCV.Float32_Value;
   use type OpenCV.Geometry.Float32_Point_Array;
   use type Subdiv.Vertex_Id;
   use type Subdiv.Voronoi_Diagram;

   subtype Points is OpenCV.Geometry.Float32_Point_Array;

   type Fixture is new AUnit.Test_Fixtures.Test_Fixture with null record;
   package Caller is new AUnit.Test_Caller (Fixture);
   Result : aliased AUnit.Test_Suites.Test_Suite;

   Square : constant OpenCV.Rect :=
     (X => 0, Y => 0, Width => 100, Height => 100);

   --  Three hull points around one interior point: the Delaunay
   --  triangulation is unique, and the interior point's Voronoi facet is the
   --  triangle of the circumcenters of its three incident triangles.
   Fixture_Points : constant Points :=
     ((X => 10.0, Y => 10.0),
      (X => 90.0, Y => 10.0),
      (X => 50.0, Y => 80.0),
      (X => 50.0, Y => 40.0));

   Interior : constant := 3;

   type Vertex_Ids is array (Natural range <>) of Subdiv.Vertex_Id;

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

   function Distance_Squared (A, B : OpenCV.Float32_Point) return Long_Float
   is ((Long_Float (A.X) - Long_Float (B.X))
       **2
       + (Long_Float (A.Y) - Long_Float (B.Y))**2);

   function Close (A, B : OpenCV.Float32_Point) return Boolean
   is (Distance_Squared (A, B) <= 1.0E-6);

   --  The circumcenter of triangle A, B, C.
   function Circumcenter
     (A, B, C : OpenCV.Float32_Point) return OpenCV.Float32_Point
   is
      Ax : constant Long_Float := Long_Float (A.X);
      Ay : constant Long_Float := Long_Float (A.Y);
      Bx : constant Long_Float := Long_Float (B.X);
      By : constant Long_Float := Long_Float (B.Y);
      Cx : constant Long_Float := Long_Float (C.X);
      Cy : constant Long_Float := Long_Float (C.Y);
      D  : constant Long_Float :=
        2.0 * (Ax * (By - Cy) + Bx * (Cy - Ay) + Cx * (Ay - By));
      A2 : constant Long_Float := Ax**2 + Ay**2;
      B2 : constant Long_Float := Bx**2 + By**2;
      C2 : constant Long_Float := Cx**2 + Cy**2;
   begin
      return
        (X =>
           OpenCV.Float32_Value
             ((A2 * (By - Cy) + B2 * (Cy - Ay) + C2 * (Ay - By)) / D),
         Y =>
           OpenCV.Float32_Value
             ((A2 * (Cx - Bx) + B2 * (Ax - Cx) + C2 * (Bx - Ax)) / D));
   end Circumcenter;

   --  Checks the documented layout: facets indexed from one, and nonempty
   --  consecutive point slices that cover Points in facet order.
   procedure Assert_Partition (Diagram : Subdiv.Voronoi_Diagram) is
      Next : Positive := 1;
   begin
      AUnit.Assertions.Assert
        (Diagram.Facets'First = 1 and then Diagram.Points'First = 1,
         "diagram arrays are indexed from one");
      for Index in Diagram.Facets'Range loop
         declare
            Facet   : constant Subdiv.Voronoi_Facet := Diagram.Facets (Index);
            Polygon : constant Points := Subdiv.Facet_Points (Diagram, Index);
         begin
            AUnit.Assertions.Assert
              (Facet.First = Next and then Facet.Last >= Facet.First,
               "facet polygons are nonempty consecutive slices");
            AUnit.Assertions.Assert
              (Polygon'First = 1
               and then Polygon = Diagram.Points (Facet.First .. Facet.Last),
               "Facet_Points returns the facet's slice indexed from one");
            Next := Facet.Last + 1;
         end;
      end loop;
      AUnit.Assertions.Assert
        (Next = Diagram.Point_Count + 1, "facet polygons cover Points");
   end Assert_Partition;

   --  Check the nearest-site property for the tested well-spaced fixtures,
   --  up to binary32 rounding; the Scale note gives no guaranteed spacing.
   procedure Assert_Nearest_Site
     (Diagram : Subdiv.Voronoi_Diagram; Sites : Points) is
   begin
      for Index in Diagram.Facets'Range loop
         if Diagram.Facets (Index).Complete then
            for Point of Subdiv.Facet_Points (Diagram, Index) loop
               declare
                  Own  : constant Long_Float :=
                    Distance_Squared
                      (Point, Diagram.Facets (Index).Site_Point);
                  Best : Long_Float := Own;
               begin
                  for Site of Sites loop
                     Best :=
                       Long_Float'Min (Best, Distance_Squared (Point, Site));
                  end loop;
                  AUnit.Assertions.Assert
                    (Own <= Best * (1.0 + 1.0E-4) + 1.0E-2,
                     "a facet point is nearest to its own site");
               end;
            end loop;
         end if;
      end loop;
   end Assert_Nearest_Site;

   --  Inserts Sources one at a time into Object, recording the vertices.
   procedure Insert_All
     (Object  : in out Subdiv.Subdivision;
      Sources : Points;
      Ids     : out Vertex_Ids) is
   begin
      for Offset in 0 .. Sources'Length - 1 loop
         Ids (Ids'First + Offset) :=
           Subdiv.Insert (Object, Sources (Sources'First + Offset));
      end loop;
   end Insert_All;

   --  Deterministic points in [0, 999) x [0, 999).
   function Scattered_Points (Count : Positive) return Points is
      State : Interfaces.Unsigned_32 := 12_345;

      function Next return OpenCV.Float32_Value is
      begin
         State := State * 1_664_525 + 1_013_904_223;
         return
           OpenCV.Float32_Value (Float (State / 2**8) / Float (2**24) * 999.0);
      end Next;
   begin
      return Result : Points (1 .. Count) do
         for Point of Result loop
            Point.X := Next;
            Point.Y := Next;
         end loop;
      end return;
   end Scattered_Points;

   procedure Fixture_Diagram (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
      Ids    : Vertex_Ids (Fixture_Points'Range);
   begin
      Insert_All (Object, Fixture_Points, Ids);
      declare
         Diagram        : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object);
         Centers        : constant Points :=
           (Circumcenter
              (Fixture_Points (0), Fixture_Points (1), Fixture_Points (3)),
            Circumcenter
              (Fixture_Points (1), Fixture_Points (2), Fixture_Points (3)),
            Circumcenter
              (Fixture_Points (2), Fixture_Points (0), Fixture_Points (3)));
         Interior_Found : Boolean := False;
      begin
         AUnit.Assertions.Assert
           (Diagram.Facet_Count = 4, "one facet per inserted point");
         Assert_Partition (Diagram);
         Assert_Nearest_Site (Diagram, Fixture_Points);
         AUnit.Assertions.Assert
           ((for all Facet of Diagram.Facets => Facet.Complete),
            "the fixture has no degenerate triangle, so every facet is "
            & "complete");
         for Index in Diagram.Facets'Range loop
            declare
               Facet : constant Subdiv.Voronoi_Facet := Diagram.Facets (Index);
               Found : Boolean := False;
            begin
               AUnit.Assertions.Assert
                 (Index = 1
                  or else Facet.Site > Diagram.Facets (Index - 1).Site,
                  "facets are in increasing site order");
               for Offset in Ids'Range loop
                  if Ids (Offset) = Facet.Site then
                     Found := True;
                     AUnit.Assertions.Assert
                       (Facet.Site_Point = Fixture_Points (Offset),
                        "a facet's site point is the inserted point");
                  end if;
               end loop;
               AUnit.Assertions.Assert
                 (Found, "every facet surrounds an inserted point");

               if Facet.Site = Ids (Interior) then
                  Interior_Found := True;
                  declare
                     Polygon : constant Points :=
                       Subdiv.Facet_Points (Diagram, Index);
                  begin
                     AUnit.Assertions.Assert
                       (Polygon'Length = 3,
                        "the interior facet has three Voronoi vertices");
                     for Center of Centers loop
                        AUnit.Assertions.Assert
                          (Close (Center, Polygon (1))
                           or else Close (Center, Polygon (2))
                           or else Close (Center, Polygon (3)),
                           "the interior facet's vertices are the "
                           & "circumcenters of its triangles");
                     end loop;
                  end;
               end if;
            end;
         end loop;
         AUnit.Assertions.Assert
           (Interior_Found, "the interior point has a facet");
      end;
   end Fixture_Diagram;

   procedure Scattered_Diagram (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Sources : constant Points := Scattered_Points (200);
      Object  : Subdiv.Subdivision :=
        Subdiv.Create ((X => 0, Y => 0, Width => 1000, Height => 1000));
      Ids     : Vertex_Ids (Sources'Range);
   begin
      Insert_All (Object, Sources, Ids);
      declare
         Diagram  : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object);
         Distinct : Natural := 0;
      begin
         for Offset in Ids'Range loop
            if (for all Earlier in Ids'First .. Offset - 1 =>
                  Ids (Earlier) /= Ids (Offset))
            then
               Distinct := Distinct + 1;
            end if;
         end loop;
         AUnit.Assertions.Assert
           (Diagram.Facet_Count = Distinct,
            "one facet per distinct inserted vertex");
         Assert_Partition (Diagram);
         Assert_Nearest_Site (Diagram, Sources);
         for Index in Diagram.Facets'Range loop
            declare
               Facet : constant Subdiv.Voronoi_Facet := Diagram.Facets (Index);
            begin
               AUnit.Assertions.Assert
                 (Index = 1
                  or else Facet.Site > Diagram.Facets (Index - 1).Site,
                  "facets are in increasing site order");
               AUnit.Assertions.Assert
                 ((for some Offset in Ids'Range =>
                     Ids (Offset) = Facet.Site
                     and then Sources (Offset) = Facet.Site_Point),
                  "every facet surrounds an inserted point at its position");
               AUnit.Assertions.Assert
                 (Subdiv.Find_Nearest (Object, Facet.Site_Point).Vertex
                  = Facet.Site,
                  "a site's own position lies in its facet");
            end;
         end loop;
      end;
   end Scattered_Diagram;

   procedure Selected_Sites (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
      Ids    : Vertex_Ids (Fixture_Points'Range);
   begin
      Insert_All (Object, Fixture_Points, Ids);
      declare
         Every    : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object);
         Selected : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets
             (Object, (Ids (Interior), Ids (0), Ids (Interior)));
         Shifted  : constant Subdiv.Vertex_Id_Array (10 .. 11) :=
           (Ids (1), Ids (2));
         Tail     : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object, Shifted);
         None     : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object, (1 .. 0 => Subdiv.No_Vertex));
      begin
         AUnit.Assertions.Assert
           (Selected.Facet_Count = 3
            and then Selected.Facets (1).Site = Ids (Interior)
            and then Selected.Facets (2).Site = Ids (0)
            and then Selected.Facets (3).Site = Ids (Interior),
            "selected facets follow the selection, repeats included");
         Assert_Partition (Selected);
         AUnit.Assertions.Assert
           (Subdiv.Facet_Points (Selected, 1)
            = Subdiv.Facet_Points (Selected, 3),
            "a repeated site repeats its facet");
         for Index in Selected.Facets'Range loop
            for Other in Every.Facets'Range loop
               if Every.Facets (Other).Site = Selected.Facets (Index).Site then
                  AUnit.Assertions.Assert
                    (Every.Facets (Other).Site_Point
                     = Selected.Facets (Index).Site_Point
                     and then Subdiv.Facet_Points (Every, Other)
                              = Subdiv.Facet_Points (Selected, Index),
                     "a selected facet equals the site's facet in the "
                     & "full diagram");
               end if;
            end loop;
         end loop;
         AUnit.Assertions.Assert
           (Tail.Facet_Count = 2
            and then Tail.Facets (1).Site = Ids (1)
            and then Tail.Facets (2).Site = Ids (2),
            "a selection with non-zero bounds is read from its first element");
         AUnit.Assertions.Assert
           (None.Facet_Count = 0 and then None.Point_Count = 0,
            "an empty selection gives an empty diagram");
         AUnit.Assertions.Assert
           (Subdiv.Voronoi_Facets (Object) = Every,
            "repeating the query without modification gives the same "
            & "diagram");
      end;
   end Selected_Sites;

   procedure Diagram_Follows_Modification (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object : Subdiv.Subdivision := Subdiv.Create (Square);
      Ids    : Vertex_Ids (Fixture_Points'Range);
      Added  : constant OpenCV.Float32_Point := (X => 30.0, Y => 20.0);
   begin
      declare
         Empty : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object);
      begin
         AUnit.Assertions.Assert
           (Empty.Facet_Count = 0 and then Empty.Point_Count = 0,
            "a subdivision without points has an empty diagram");
      end;

      Insert_All (Object, Fixture_Points, Ids);
      declare
         Before   : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object);
         Added_Id : constant Subdiv.Vertex_Id := Subdiv.Insert (Object, Added);
         After    : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object);
      begin
         AUnit.Assertions.Assert
           (Before.Facet_Count = 4 and then After.Facet_Count = 5,
            "an insertion adds a facet");
         AUnit.Assertions.Assert
           ((for some Facet of After.Facets =>
               Facet.Site = Added_Id and then Facet.Site_Point = Added),
            "the inserted point has a facet");
         Assert_Partition (After);
         Assert_Nearest_Site (After, Fixture_Points & Added);
      end;

      Subdiv.Reset (Object, Square);
      declare
         Cleared : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object);
      begin
         AUnit.Assertions.Assert
           (Cleared.Facet_Count = 0, "Reset empties the diagram");
      end;
   end Diagram_Follows_Modification;

   procedure Rejects_Invalid_Sites (Test : in out Fixture) is
      pragma Unreferenced (Test);
      Object  : Subdiv.Subdivision := Subdiv.Create (Square);
      Unready : Subdiv.Subdivision;
      Ids     : Vertex_Ids (Fixture_Points'Range);
      Voronoi : Subdiv.Vertex_Id := Subdiv.No_Vertex;

      procedure Select_No_Vertex is
         Ignored : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object, (1 => Subdiv.No_Vertex));
      begin
         null;
      end Select_No_Vertex;

      procedure Select_Super_Vertex is
         Ignored : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object, (1 => 2));
      begin
         null;
      end Select_Super_Vertex;

      procedure Select_Beyond_Storage is
         Ignored : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object, (1 => Subdiv.Vertex_Id'Last));
      begin
         null;
      end Select_Beyond_Storage;

      procedure Select_Voronoi_Vertex is
         Ignored : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object, (1 => Voronoi));
      begin
         null;
      end Select_Voronoi_Vertex;

      procedure Select_Valid_Then_Invalid is
         Ignored : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object, (Ids (0), Subdiv.No_Vertex));
      begin
         null;
      end Select_Valid_Then_Invalid;

      procedure Every_Unready is
         Ignored : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Unready);
      begin
         null;
      end Every_Unready;

      procedure Selected_Unready is
         Ignored : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Unready, (1 => 4));
      begin
         null;
      end Selected_Unready;

      procedure Empty_Selection_Unready is
         Ignored : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Unready, (1 .. 0 => Subdiv.No_Vertex));
      begin
         null;
      end Empty_Selection_Unready;
   begin
      Insert_All (Object, Fixture_Points, Ids);
      declare
         Ignored : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object);
      begin
         null;
      end;
      --  After the Voronoi computation, a dual edge of a Delaunay edge
      --  between inserted points starts at a Voronoi vertex.
      for Edge of Subdiv.Leading_Edge_List (Object) loop
         if Subdiv.Origin (Object, Edge) > 3
           and then Subdiv.Destination (Object, Edge) > 3
         then
            Voronoi :=
              Subdiv.Origin
                (Object, Subdiv.Rotate (Object, Edge, Subdiv.Rotated_Edge));
         end if;
      end loop;
      AUnit.Assertions.Assert
        (Voronoi /= Subdiv.No_Vertex, "the fixture has a Voronoi vertex");

      Assert_Raises_OpenCV_Error
        (Select_No_Vertex'Access, "No_Vertex is rejected");
      Assert_Raises_OpenCV_Error
        (Select_Super_Vertex'Access, "super-triangle vertices are rejected");
      Assert_Raises_OpenCV_Error
        (Select_Beyond_Storage'Access,
         "a vertex beyond native storage is rejected");
      Assert_Raises_OpenCV_Error
        (Select_Voronoi_Vertex'Access, "a Voronoi vertex is rejected");
      Assert_Raises_OpenCV_Error
        (Select_Valid_Then_Invalid'Access,
         "one invalid site rejects the whole selection");
      Assert_Raises_OpenCV_Error
        (Every_Unready'Access, "the full diagram requires a ready object");
      Assert_Raises_OpenCV_Error
        (Selected_Unready'Access, "a selection requires a ready object");
      Assert_Raises_OpenCV_Error
        (Empty_Selection_Unready'Access,
         "an empty selection requires a ready object");
      AUnit.Assertions.Assert
        (Subdiv.Is_Ready (Object),
         "rejected selections leave the subdivision ready");
   end Rejects_Invalid_Sites;

   --  Checks that the Ada diagram of Sources, inserted in order into a
   --  Subdivision of Area, preserves the native facets element for element,
   --  including each facet's completeness. OpenCV is deterministic, so a
   --  raw handle given the same points holds the same triangulation. An
   --  incomplete facet must contain OpenCV's (0, 0) placeholder. When
   --  Well_Spaced, the fixture also checks the nearest-site property for
   --  complete facets; this is empirical, not a spacing guarantee.
   procedure Assert_Preserves_Native_Facets
     (Area : OpenCV.Rect; Sources : Points; Well_Spaced : Boolean)
   is
      Bounds   : aliased constant C_API.Rect_I32 :=
        (X      => Interfaces.Integer_32 (Area.X),
         Y      => Interfaces.Integer_32 (Area.Y),
         Width  => Interfaces.Integer_32 (Area.Width),
         Height => Interfaces.Integer_32 (Area.Height));
      Handle   : aliased C_API.Subdiv2D_Handle := null;
      Batch    : aliased C_API.Point_F32_Array (0 .. Sources'Length - 1);
      Facets   : aliased C_API.C_Voronoi_Facet_Array (0 .. 15);
      Native   : aliased C_API.Point_F32_Array (0 .. 255);
      Inserted : aliased Interfaces.Integer_32 := 0;
      Facet_N  : aliased Interfaces.Integer_32 := 0;
      Point_N  : aliased Interfaces.Integer_32 := 0;
      Status   : C_API.Status;
      Object   : Subdiv.Subdivision := Subdiv.Create (Area);
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
          (Handle, Batch (0)'Access, Batch'Length, Inserted'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Inserted = Batch'Length,
         "the raw points are inserted");
      Subdiv.Insert (Object, Sources);
      Status :=
        C_API.Subdiv2D_Get_Voronoi_Facets
          (Handle,
           C_API.Subdiv2D_Voronoi_Select_All,
           null,
           0,
           Facets (0)'Access,
           Facets'Length,
           Native (0)'Access,
           Native'Length,
           Facet_N'Access,
           Point_N'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Facet_N = Sources'Length,
         "the raw diagram has one facet per point");

      declare
         Diagram : constant Subdiv.Voronoi_Diagram :=
           Subdiv.Voronoi_Facets (Object);
      begin
         AUnit.Assertions.Assert
           (Diagram.Facet_Count = Natural (Facet_N)
            and then Diagram.Point_Count = Natural (Point_N),
            "the Ada diagram has the native sizes");
         for Index in Diagram.Facets'Range loop
            declare
               Raw   : constant C_API.C_Voronoi_Facet := Facets (Index - 1);
               Facet : constant Subdiv.Voronoi_Facet := Diagram.Facets (Index);
            begin
               AUnit.Assertions.Assert
                 (Interfaces.Integer_32 (Facet.Site) = Raw.Site
                  and then Facet.Site_Point.X
                           = OpenCV.Float32_Value (Raw.Center_X)
                  and then Facet.Site_Point.Y
                           = OpenCV.Float32_Value (Raw.Center_Y)
                  and then Facet.First = Natural (Raw.First_Point) + 1
                  and then Facet.Last
                           = Natural (Raw.First_Point + Raw.Point_Count)
                  and then Facet.Complete = (Raw.Complete = 1),
                  "each facet preserves the native facet");
               AUnit.Assertions.Assert
                 (Facet.Complete
                  or else (for some Point of
                             Subdiv.Facet_Points (Diagram, Index) =>
                             Point = (X => 0.0, Y => 0.0)),
                  "an incomplete facet holds OpenCV's placeholder point");
            end;
         end loop;
         for Index in Diagram.Points'Range loop
            AUnit.Assertions.Assert
              (Diagram.Points (Index).X
               = OpenCV.Float32_Value (Native (Index - 1).X)
               and then Diagram.Points (Index).Y
                        = OpenCV.Float32_Value (Native (Index - 1).Y),
               "each facet point preserves the native point");
         end loop;
         Assert_Partition (Diagram);
         if Well_Spaced then
            Assert_Nearest_Site (Diagram, Sources);
         end if;
      end;
      C_API.Subdiv2D_Destroy (Handle);
   exception
      when others =>
         C_API.Subdiv2D_Destroy (Handle);
         raise;
   end Assert_Preserves_Native_Facets;

   procedure Preserves_C_ABI_Facets (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Preserves_Native_Facets
        (Square,
         Fixture_Points
         & Points'
             ((X => 30.0, Y => 20.0),
              (X => 70.0, Y => 30.0),
              (X => 20.0, Y => 60.0),
              (X => 80.0, Y => 70.0)),
         Well_Spaced => True);
   end Preserves_C_ABI_Facets;

   --  Points about 1E-4 to 4E-4 apart, much closer than in the well-spaced
   --  fixtures. OpenCV can leave Voronoi vertices uncomputed. Each facet's
   --  completeness must still match the native report, and the diagram must
   --  still be returned rather than rejected as a whole.
   procedure Closely_Spaced_Points (Test : in out Fixture) is
      pragma Unreferenced (Test);
   begin
      Assert_Preserves_Native_Facets
        ((X => 0, Y => 0, Width => 1, Height => 1),
         ((X => 0.500_299_99, Y => 0.500_199_974),
          (X => 0.5, Y => 0.500_199_974),
          (X => 0.500_299_99, Y => 0.500_400_007),
          (X => 0.500_400_007, Y => 0.500_199_974)),
         Well_Spaced => False);
   end Closely_Spaced_Points;

   procedure C_ABI_Validation (Test : in out Fixture) is
      pragma Unreferenced (Test);

      Bounds    : aliased constant C_API.Rect_I32 :=
        (X => 0, Y => 0, Width => 100, Height => 100);
      Handle    : aliased C_API.Subdiv2D_Handle := null;
      Batch     : aliased C_API.Point_F32_Array (0 .. 3) :=
        ((X => 10.0, Y => 10.0),
         (X => 90.0, Y => 10.0),
         (X => 50.0, Y => 80.0),
         (X => 50.0, Y => 40.0));
      Listed    : aliased C_API.Int32_Array (0 .. 1) := (0, 0);
      Mixed     : aliased C_API.Int32_Array (0 .. 3) := (others => 0);
      Facets    : aliased C_API.C_Voronoi_Facet_Array (0 .. 7);
      Native    : aliased C_API.Point_F32_Array (0 .. 63);
      Inserted  : aliased Interfaces.Integer_32 := 0;
      Facet_N   : aliased Interfaces.Integer_32 := 0;
      Point_N   : aliased Interfaces.Integer_32 := 0;
      Status    : C_API.Status;
      All_Facet : Interfaces.Integer_32;
      All_Point : Interfaces.Integer_32;

      function Counts
        (Selection : Interfaces.Integer_32;
         Count     : Interfaces.Integer_32;
         Use_List  : Boolean := True) return C_API.Status is
      begin
         Facet_N := 99;
         Point_N := 99;
         if Use_List then
            return
              C_API.Subdiv2D_Voronoi_Facet_Counts
                (Handle,
                 Selection,
                 Listed (0)'Access,
                 Count,
                 Facet_N'Access,
                 Point_N'Access);
         else
            return
              C_API.Subdiv2D_Voronoi_Facet_Counts
                (Handle,
                 Selection,
                 null,
                 Count,
                 Facet_N'Access,
                 Point_N'Access);
         end if;
      end Counts;

      function Fill
        (Facet_Capacity, Point_Capacity : Interfaces.Integer_32)
         return C_API.Status is
      begin
         Facet_N := 99;
         Point_N := 99;
         return
           C_API.Subdiv2D_Get_Voronoi_Facets
             (Handle,
              C_API.Subdiv2D_Voronoi_Select_All,
              null,
              0,
              Facets (0)'Access,
              Facet_Capacity,
              Native (0)'Access,
              Point_Capacity,
              Facet_N'Access,
              Point_N'Access);
      end Fill;

      function Zeroed return Boolean
      is (Facet_N = 0 and then Point_N = 0);
   begin
      Status := C_API.Subdiv2D_Create (Bounds'Access, Handle'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success, "a raw subdivision is created");
      Status :=
        C_API.Subdiv2D_Insert_Points
          (Handle, Batch (0)'Access, 4, Inserted'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Inserted = 4,
         "the raw fixture is inserted");

      --  Output and handle validation.
      Status :=
        C_API.Subdiv2D_Voronoi_Facet_Counts
          (Handle,
           C_API.Subdiv2D_Voronoi_Select_All,
           null,
           0,
           null,
           Point_N'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument,
         "a null facet count output is rejected");
      Point_N := 99;
      Status :=
        C_API.Subdiv2D_Voronoi_Facet_Counts
          (Handle,
           C_API.Subdiv2D_Voronoi_Select_All,
           null,
           0,
           Facet_N'Access,
           null);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Facet_N = 0,
         "a null point count output is rejected after zeroing the other");
      Facet_N := 99;
      Point_N := 99;
      Status :=
        C_API.Subdiv2D_Voronoi_Facet_Counts
          (null,
           C_API.Subdiv2D_Voronoi_Select_All,
           null,
           0,
           Facet_N'Access,
           Point_N'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "a null handle is rejected");

      --  Selection validation.
      for Selection of C_API.Int32_Array'(-1, 2) loop
         Status := Counts (Selection, 0, Use_List => False);
         AUnit.Assertions.Assert
           (Status = C_API.Error_Invalid_Argument and then Zeroed,
            "selection" & Selection'Image & " is rejected");
      end loop;
      Status := Counts (C_API.Subdiv2D_Voronoi_Select_All, 0);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "selecting every vertex rejects a vertex list");
      Status :=
        Counts (C_API.Subdiv2D_Voronoi_Select_All, 1, Use_List => False);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "selecting every vertex rejects a vertex count");
      Status := Counts (C_API.Subdiv2D_Voronoi_Select_Listed, -1);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "a negative vertex count is rejected");
      Status :=
        Counts (C_API.Subdiv2D_Voronoi_Select_Listed, 1, Use_List => False);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "a null vertex list with positive count is rejected");
      Listed := (4, -1);
      Status := Counts (C_API.Subdiv2D_Voronoi_Select_Listed, 2);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "a negative vertex identifier is rejected");
      Listed := (4, 1_000_000);
      Status := Counts (C_API.Subdiv2D_Voronoi_Select_Listed, 2);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "a vertex beyond native storage is rejected");
      Status := Counts (C_API.Subdiv2D_Voronoi_Select_Listed, 1);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Facet_N <= 1,
         "only the counted prefix of the list is read");

      --  Unlike OpenCV, an empty list selects nothing; free slots produce
      --  no facet; a super-triangle vertex produces one.
      Status :=
        Counts (C_API.Subdiv2D_Voronoi_Select_Listed, 0, Use_List => False);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Zeroed,
         "an empty list selects nothing");
      Listed := (0, 0);
      Status := Counts (C_API.Subdiv2D_Voronoi_Select_Listed, 2);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Zeroed,
         "a free slot produces no facet");
      Listed := (1, 0);
      Status := Counts (C_API.Subdiv2D_Voronoi_Select_Listed, 1);
      AUnit.Assertions.Assert
        (Status = C_API.Success and then Facet_N = 1,
         "a super-triangle vertex produces a facet");
      Status :=
        C_API.Subdiv2D_Get_Voronoi_Facets
          (Handle,
           C_API.Subdiv2D_Voronoi_Select_Listed,
           Listed (0)'Access,
           1,
           Facets (0)'Access,
           Facets'Length,
           Native (0)'Access,
           Native'Length,
           Facet_N'Access,
           Point_N'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Facet_N = 1
         and then Facets (0).Site = 1
         and then Facets (0).Complete = 0,
         "a super-triangle vertex's facet is incomplete, since it borders "
         & "the facet outside the super-triangle");

      Status := Counts (C_API.Subdiv2D_Voronoi_Select_All, 0, False);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Facet_N = 4
         and then Point_N >= Facet_N,
         "every inserted point has a nonempty facet");
      All_Facet := Facet_N;
      All_Point := Point_N;

      --  Capacity validation publishes nothing.
      Status := Fill (All_Facet - 1, All_Point);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument
         and then Zeroed
         and then C_API.Last_Error_Message'Length > 0,
         "an insufficient facet capacity publishes nothing");
      Status := Fill (All_Facet, All_Point - 1);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "an insufficient point capacity publishes nothing");
      Status := Fill (-1, All_Point);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "a negative capacity is rejected");
      Facet_N := 99;
      Status :=
        C_API.Subdiv2D_Get_Voronoi_Facets
          (Handle,
           C_API.Subdiv2D_Voronoi_Select_All,
           null,
           0,
           null,
           8,
           Native (0)'Access,
           64,
           Facet_N'Access,
           Point_N'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "a null facet buffer with positive capacity is rejected");
      Facet_N := 99;
      Status :=
        C_API.Subdiv2D_Get_Voronoi_Facets
          (Handle,
           C_API.Subdiv2D_Voronoi_Select_All,
           null,
           0,
           Facets (0)'Access,
           8,
           null,
           64,
           Facet_N'Access,
           Point_N'Access);
      AUnit.Assertions.Assert
        (Status = C_API.Error_Invalid_Argument and then Zeroed,
         "a null point buffer with positive capacity is rejected");

      --  Skipped entries shift the remaining facets: a free slot and a
      --  Voronoi vertex produce nothing, and the others keep their order.
      declare
         Voronoi  : Interfaces.Integer_32 := 0;
         Site     : aliased Interfaces.Integer_32 := 0;
         Position : aliased C_API.Point_F32 := (X => 0.0, Y => 0.0);
         First    : aliased Interfaces.Integer_32 := 0;
         Kind     : aliased Interfaces.Integer_32 := 0;
      begin
         Status :=
           C_API.Subdiv2D_Find_Nearest
             (Handle, 10.0, 10.0, Site'Access, Position'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success and then Site > 3,
            "an inserted point's vertex is found");
         for Candidate in Interfaces.Integer_32 range 0 .. 63 loop
            if Voronoi = 0
              and then C_API.Subdiv2D_Get_Vertex
                         (Handle,
                          Candidate,
                          Position'Access,
                          First'Access,
                          Kind'Access)
                       = C_API.Success
              and then Kind = C_API.Subdiv2D_Vertex_Voronoi
            then
               Voronoi := Candidate;
            end if;
         end loop;
         AUnit.Assertions.Assert
           (Voronoi /= 0, "the computed diagram has a Voronoi vertex");
         Mixed := (0, Voronoi, Site, 1);
         Status :=
           C_API.Subdiv2D_Get_Voronoi_Facets
             (Handle,
              C_API.Subdiv2D_Voronoi_Select_Listed,
              Mixed (0)'Access,
              4,
              Facets (0)'Access,
              Facets'Length,
              Native (0)'Access,
              Native'Length,
              Facet_N'Access,
              Point_N'Access);
         AUnit.Assertions.Assert
           (Status = C_API.Success
            and then Facet_N = 2
            and then Facets (0).Site = Site
            and then Facets (0).Complete = 1
            and then Facets (1).Site = 1
            and then Facets (1).Complete = 0,
            "skipped entries leave the kept sites in order");
      end;

      Status := Fill (All_Facet, All_Point);
      AUnit.Assertions.Assert
        (Status = C_API.Success
         and then Facet_N = All_Facet
         and then Point_N = All_Point,
         "exact capacities from the counts hold the facets");
      declare
         Next : Interfaces.Integer_32 := 0;
      begin
         for Index in 0 .. Natural (Facet_N) - 1 loop
            AUnit.Assertions.Assert
              (Facets (Index).First_Point = Next
               and then Facets (Index).Point_Count > 0
               and then Facets (Index).Site > 3
               and then Facets (Index).Complete = 1
               and then (Index = 0
                         or else Facets (Index).Site
                                 > Facets (Index - 1).Site),
               "raw facets are complete, consecutive, nonempty, and in "
               & "increasing site order");
            Next := Next + Facets (Index).Point_Count;
         end loop;
         AUnit.Assertions.Assert
           (Next = Point_N, "raw facet points cover the point list");
      end;

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
           ("Subdiv2D Voronoi fixture diagram", Fixture_Diagram'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Voronoi scattered diagram", Scattered_Diagram'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Voronoi selected sites", Selected_Sites'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Voronoi diagram follows modification",
            Diagram_Follows_Modification'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Voronoi rejects invalid sites",
            Rejects_Invalid_Sites'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Voronoi closely spaced points",
            Closely_Spaced_Points'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Voronoi preserves C ABI facets",
            Preserves_C_ABI_Facets'Access));
      Result.Add_Test
        (Caller.Create
           ("Subdiv2D Voronoi C ABI validation", C_ABI_Validation'Access));
      return Result'Access;
   end Suite;

end Subdiv2D_Voronoi_Tests;
