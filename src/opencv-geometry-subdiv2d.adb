with Ada.Exceptions;
with Ada.Unchecked_Deallocation;
with Interfaces;
with Interfaces.C;
with OpenCV.Geometry.Internal.Subdivision;

package body OpenCV.Geometry.Subdiv2D is

   package C_API renames OpenCV.Geometry.Internal.C_API;

   use type C_API.Status;
   use type C_API.Subdiv2D_Handle;
   use type Interfaces.Integer_32;

   procedure Raise_Error (Message : String)
   with No_Return;

   procedure Raise_Error (Message : String) is
   begin
      Ada.Exceptions.Raise_Exception (OpenCV.OpenCV_Error'Identity, Message);
   end Raise_Error;

   --  Reads the diagnostic only on failure, so a successful call performs no
   --  further native call or allocation.
   procedure Raise_On_Error (Status : C_API.Status; Operation : String) is
   begin
      if Status = C_API.Success then
         return;
      end if;

      declare
         Diagnostic : constant String := C_API.Last_Error_Message;
      begin
         if Diagnostic'Length = 0 then
            Raise_Error (Operation & " failed");
         else
            Raise_Error (Operation & " failed: " & Diagnostic);
         end if;
      end;
   end Raise_On_Error;

   function Is_Finite (Value : OpenCV.Float32_Value) return Boolean is
      pragma Suppress (Validity_Check);
      use type OpenCV.Float32_Value;
   begin
      return
        Value = Value
        and then Value >= OpenCV.Float32_Value'First
        and then Value <= OpenCV.Float32_Value'Last;
   end Is_Finite;

   procedure Validate_Point (Point : OpenCV.Float32_Point; Operation : String)
   is
      pragma Suppress (Validity_Check);
   begin
      if not Is_Finite (Point.X) or else not Is_Finite (Point.Y) then
         Raise_Error (Operation & " requires finite point coordinates");
      end if;
   end Validate_Point;

   --  Raises OpenCV_Error unless Object owns a native subdivision. The shim
   --  itself rejects a native subdivision that is not usable.
   function Native_Handle
     (Object : Subdivision; Operation : String) return C_API.Subdiv2D_Handle is
   begin
      if Object.Handle = null then
         Raise_Error
           (Operation
            & " requires a subdivision initialized by Create or Reset");
      end if;
      return Object.Handle;
   end Native_Handle;

   function To_C_Rect (Bounds : OpenCV.Rect) return C_API.Rect_I32 is
   begin
      return
        (X      => Interfaces.Integer_32 (Bounds.X),
         Y      => Interfaces.Integer_32 (Bounds.Y),
         Width  => Interfaces.Integer_32 (Bounds.Width),
         Height => Interfaces.Integer_32 (Bounds.Height));
   end To_C_Rect;

   function To_Vertex_Id
     (Value : Interfaces.Integer_32; Operation : String) return Vertex_Id is
   begin
      if Value <= 0 then
         Raise_Error (Operation & " failed: OpenCV returned no vertex");
      end if;
      return Vertex_Id (Value);
   end To_Vertex_Id;

   function To_Edge_Id
     (Value : Interfaces.Integer_32; Operation : String) return Edge_Id is
   begin
      if Value <= 0 then
         Raise_Error (Operation & " failed: OpenCV returned no edge");
      end if;
      return Edge_Id (Value);
   end To_Edge_Id;

   function Create (Bounds : OpenCV.Rect) return Subdivision is
   begin
      return Result : Subdivision do
         Reset (Result, Bounds);
      end return;
   end Create;

   procedure Reset (Object : in out Subdivision; Bounds : OpenCV.Rect) is
      Native_Bounds : aliased constant C_API.Rect_I32 := To_C_Rect (Bounds);
      Status        : C_API.Status;
   begin
      if Bounds.Width = 0 or else Bounds.Height = 0 then
         Raise_Error
           ("Subdiv2D.Reset requires a positive Bounds width and height");
      end if;

      if Object.Handle = null then
         declare
            Handle : aliased C_API.Subdiv2D_Handle := null;
         begin
            Status :=
              C_API.Subdiv2D_Create (Native_Bounds'Access, Handle'Access);
            --  The ABI publishes null unless creation succeeded. Take
            --  ownership before anything else can raise.
            Object.Handle := Handle;
            Raise_On_Error (Status, "Subdiv2D.Reset");
         end;
      else
         Status :=
           C_API.Subdiv2D_Init_Delaunay (Object.Handle, Native_Bounds'Access);
         Raise_On_Error (Status, "Subdiv2D.Reset");
      end if;

      Object.Bounds := Bounds;
      Object.Has_Bounds := True;
   end Reset;

   function Is_Ready (Object : Subdivision) return Boolean is
   begin
      return
        Object.Handle /= null
        and then C_API.Subdiv2D_Is_Usable (Object.Handle) = 1;
   end Is_Ready;

   function Bounds (Object : Subdivision) return OpenCV.Rect is
   begin
      if not Object.Has_Bounds then
         Raise_Error
           ("Subdiv2D.Bounds requires a subdivision initialized by Create or "
            & "Reset");
      end if;
      return Object.Bounds;
   end Bounds;

   function Insert
     (Object : in out Subdivision; Point : OpenCV.Float32_Point)
      return Vertex_Id
   is
      Vertex : aliased Interfaces.Integer_32 := 0;
      Status : C_API.Status;
   begin
      Validate_Point (Point, "Subdiv2D.Insert");
      Status :=
        C_API.Subdiv2D_Insert
          (Native_Handle (Object, "Subdiv2D.Insert"),
           Interfaces.C.C_float (Point.X),
           Interfaces.C.C_float (Point.Y),
           Vertex'Access);
      Raise_On_Error (Status, "Subdiv2D.Insert");
      return To_Vertex_Id (Vertex, "Subdiv2D.Insert");
   end Insert;

   --  Points cross the ABI in chunks of this many, so a large array needs no
   --  stack storage proportional to its length.
   Insert_Chunk_Length : constant := 4096;

   procedure Insert (Object : in out Subdivision; Points : Float32_Point_Array)
   is
      Handle : C_API.Subdiv2D_Handle;
      Status : C_API.Status;
   begin
      for Point of Points loop
         Validate_Point (Point, "Subdiv2D.Insert");
      end loop;
      Handle := Native_Handle (Object, "Subdiv2D.Insert");

      if Points'Length = 0 then
         declare
            Inserted : aliased Interfaces.Integer_32 := 0;
         begin
            Status :=
              C_API.Subdiv2D_Insert_Points (Handle, null, 0, Inserted'Access);
            Raise_On_Error (Status, "Subdiv2D.Insert");
            return;
         end;
      end if;

      declare
         Chunk     : C_API.Point_F32_Array (0 .. Insert_Chunk_Length - 1);
         First     : Natural := Points'First;
         Remaining : Natural := Points'Length;
      begin
         while Remaining > 0 loop
            declare
               Count    : constant Natural :=
                 Natural'Min (Remaining, Insert_Chunk_Length);
               Inserted : aliased Interfaces.Integer_32 := 0;
            begin
               for Offset in 0 .. Count - 1 loop
                  Chunk (Offset) :=
                    (X => Interfaces.C.C_float (Points (First + Offset).X),
                     Y => Interfaces.C.C_float (Points (First + Offset).Y));
               end loop;
               Status :=
                 C_API.Subdiv2D_Insert_Points
                   (Handle,
                    Chunk (Chunk'First)'Access,
                    Interfaces.Integer_32 (Count),
                    Inserted'Access);
               if Status /= C_API.Success then
                  Raise_On_Error
                    (Status,
                     "Subdiv2D.Insert of the point at index"
                     & Natural'Image (First + Natural (Inserted)));
               end if;
               Remaining := Remaining - Count;
               if Remaining > 0 then
                  First := First + Count;
               end if;
            end;
         end loop;
      end;
   end Insert;

   function Locate
     (Object : in out Subdivision; Point : OpenCV.Float32_Point)
      return Locate_Result
   is
      Location : aliased Interfaces.Integer_32 := 0;
      Edge     : aliased Interfaces.Integer_32 := 0;
      Vertex   : aliased Interfaces.Integer_32 := 0;
      Status   : C_API.Status;
   begin
      Validate_Point (Point, "Subdiv2D.Locate");
      Status :=
        C_API.Subdiv2D_Locate
          (Native_Handle (Object, "Subdiv2D.Locate"),
           Interfaces.C.C_float (Point.X),
           Interfaces.C.C_float (Point.Y),
           Location'Access,
           Edge'Access,
           Vertex'Access);
      Raise_On_Error (Status, "Subdiv2D.Locate");

      if Location = C_API.Subdiv2D_Location_Inside then
         return
           (Kind => Inside_Facet,
            Edge => To_Edge_Id (Edge, "Subdiv2D.Locate"));
      elsif Location = C_API.Subdiv2D_Location_On_Edge then
         return
           (Kind => On_Edge, Edge => To_Edge_Id (Edge, "Subdiv2D.Locate"));
      elsif Location = C_API.Subdiv2D_Location_On_Vertex then
         return
           (Kind   => On_Vertex,
            Vertex => To_Vertex_Id (Vertex, "Subdiv2D.Locate"));
      elsif Location = C_API.Subdiv2D_Location_Outside_Rect then
         Raise_Error
           ("Subdiv2D.Locate failed: Point is outside the subdivision bounds");
      else
         Raise_Error ("Subdiv2D.Locate failed: OpenCV could not locate Point");
      end if;
   end Locate;

   function Find_Nearest
     (Object : in out Subdivision; Point : OpenCV.Float32_Point)
      return Nearest_Result
   is
      Vertex   : aliased Interfaces.Integer_32 := 0;
      Position : aliased C_API.Point_F32 := (X => 0.0, Y => 0.0);
      Status   : C_API.Status;
   begin
      Validate_Point (Point, "Subdiv2D.Find_Nearest");
      Status :=
        C_API.Subdiv2D_Find_Nearest
          (Native_Handle (Object, "Subdiv2D.Find_Nearest"),
           Interfaces.C.C_float (Point.X),
           Interfaces.C.C_float (Point.Y),
           Vertex'Access,
           Position'Access);
      Raise_On_Error (Status, "Subdiv2D.Find_Nearest");
      return
        (Vertex => To_Vertex_Id (Vertex, "Subdiv2D.Find_Nearest"),
         Point  =>
           (X => OpenCV.Float32_Value (Position.X),
            Y => OpenCV.Float32_Value (Position.Y)));
   end Find_Nearest;

   function Quad_Edge_Count
     (Object : Subdivision; Operation : String)
      return Internal.Subdivision.Quad_Edge_Count
   is
      Count  : aliased Interfaces.Integer_32 := 0;
      Status : C_API.Status;
   begin
      Status :=
        C_API.Subdiv2D_Quad_Edge_Count
          (Native_Handle (Object, Operation), Count'Access);
      Raise_On_Error (Status, Operation);
      if Count < 0 or else Count > Internal.Subdivision.Maximum_Quad_Edges then
         Raise_Error (Operation & " failed: invalid native quad-edge count");
      end if;
      return Natural (Count);
   end Quad_Edge_Count;

   --  Reads one native list into an Ada-owned array indexed 1 .. N. The C
   --  buffer has Capacity elements, which the caller derives from the native
   --  quad-edge count, and lives on the heap so large triangulations need no
   --  proportional stack storage; the result is built in place.
   generic
      type Native_Element is private;
      type Native_Array is array (Natural range <>) of aliased Native_Element;
      type Public_Element is private;
      type Public_Array is array (Natural range <>) of Public_Element;
      with
        function Fill
          (Handle       : C_API.Subdiv2D_Handle;
           Out_Items    : access Native_Element;
           Out_Capacity : Interfaces.Integer_32;
           Out_Count    : access Interfaces.Integer_32) return C_API.Status;
      with
        function Convert
          (Item : Native_Element; Operation : String) return Public_Element;
   function Read_List
     (Object : Subdivision; Capacity : Natural; Operation : String)
      return Public_Array;

   function Read_List
     (Object : Subdivision; Capacity : Natural; Operation : String)
      return Public_Array
   is
      type Buffer_Access is access Native_Array;

      procedure Free is new
        Ada.Unchecked_Deallocation (Native_Array, Buffer_Access);

      Handle : constant C_API.Subdiv2D_Handle :=
        Native_Handle (Object, Operation);
      Count  : aliased Interfaces.Integer_32 := 0;
      Status : C_API.Status;
   begin
      if Capacity = 0 then
         Status := Fill (Handle, null, 0, Count'Access);
         Raise_On_Error (Status, Operation);
         if Count /= 0 then
            Raise_Error (Operation & " failed: invalid native count");
         end if;
         return Empty : Public_Array (1 .. 0);
      end if;

      declare
         Buffer : Buffer_Access := new Native_Array (0 .. Capacity - 1);
      begin
         Status :=
           Fill
             (Handle,
              Buffer (Buffer'First)'Access,
              Interfaces.Integer_32 (Capacity),
              Count'Access);
         Raise_On_Error (Status, Operation);
         if Count < 0 or else Natural (Count) > Capacity then
            Raise_Error (Operation & " failed: invalid native count");
         end if;

         return Result : Public_Array (1 .. Natural (Count)) do
            for Index in Result'Range loop
               Result (Index) := Convert (Buffer (Index - 1), Operation);
            end loop;
            Free (Buffer);
         end return;
      exception
         when others =>
            Free (Buffer);
            raise;
      end;
   end Read_List;

   function To_Public_Point
     (X, Y : Interfaces.C.C_float) return OpenCV.Float32_Point is
   begin
      return (X => OpenCV.Float32_Value (X), Y => OpenCV.Float32_Value (Y));
   end To_Public_Point;

   function To_Edge_Segment
     (Item : C_API.C_Edge_Segment; Operation : String) return Edge_Segment
   is
      pragma Unreferenced (Operation);
   begin
      return
        (Origin      => To_Public_Point (Item.Origin_X, Item.Origin_Y),
         Destination =>
           To_Public_Point (Item.Destination_X, Item.Destination_Y));
   end To_Edge_Segment;

   function To_Leading_Edge
     (Item : Interfaces.Integer_32; Operation : String) return Edge_Id is
   begin
      return To_Edge_Id (Item, Operation);
   end To_Leading_Edge;

   function To_Triangle
     (Item : C_API.C_Triangle; Operation : String)
      return OpenCV.Geometry.Triangle_Vertices
   is
      pragma Unreferenced (Operation);
   begin
      return
        (1 => To_Public_Point (Item.V0_X, Item.V0_Y),
         2 => To_Public_Point (Item.V1_X, Item.V1_Y),
         3 => To_Public_Point (Item.V2_X, Item.V2_Y));
   end To_Triangle;

   function Read_Edge_List is new
     Read_List
       (Native_Element => C_API.C_Edge_Segment,
        Native_Array   => C_API.C_Edge_Segment_Array,
        Public_Element => Edge_Segment,
        Public_Array   => Edge_Segment_Array,
        Fill           => C_API.Subdiv2D_Get_Edge_List,
        Convert        => To_Edge_Segment);

   function Read_Leading_Edge_List is new
     Read_List
       (Native_Element => Interfaces.Integer_32,
        Native_Array   => C_API.Int32_Array,
        Public_Element => Edge_Id,
        Public_Array   => Edge_Id_Array,
        Fill           => C_API.Subdiv2D_Get_Leading_Edge_List,
        Convert        => To_Leading_Edge);

   function Read_Triangle_List is new
     Read_List
       (Native_Element => C_API.C_Triangle,
        Native_Array   => C_API.C_Triangle_Array,
        Public_Element => OpenCV.Geometry.Triangle_Vertices,
        Public_Array   => Triangle_Array,
        Fill           => C_API.Subdiv2D_Get_Triangle_List,
        Convert        => To_Triangle);

   function Edge_List (Object : Subdivision) return Edge_Segment_Array is
      Operation : constant String := "Subdiv2D.Edge_List";
   begin
      return
        Read_Edge_List
          (Object,
           Internal.Subdivision.Edge_List_Capacity
             (Quad_Edge_Count (Object, Operation)),
           Operation);
   end Edge_List;

   function Leading_Edge_List (Object : Subdivision) return Edge_Id_Array is
      Operation : constant String := "Subdiv2D.Leading_Edge_List";
   begin
      return
        Read_Leading_Edge_List
          (Object,
           Internal.Subdivision.Facet_List_Capacity
             (Quad_Edge_Count (Object, Operation)),
           Operation);
   end Leading_Edge_List;

   function Triangle_List (Object : Subdivision) return Triangle_Array is
      Operation : constant String := "Subdiv2D.Triangle_List";
   begin
      return
        Read_Triangle_List
          (Object,
           Internal.Subdivision.Facet_List_Capacity
             (Quad_Edge_Count (Object, Operation)),
           Operation);
   end Triangle_List;

   --  Rejects No_Edge and the other identifiers 1 .. 3 of OpenCV's reserved
   --  null edge. The shim rejects identifiers beyond native storage.
   function Checked_Edge
     (Edge : Edge_Id; Operation : String) return Interfaces.Integer_32 is
   begin
      if Edge < 4 then
         Raise_Error
           (Operation & " requires an edge identifier, not the null edge");
      end if;
      return Interfaces.Integer_32 (Edge);
   end Checked_Edge;

   function To_C_Navigation
     (Direction : Edge_Navigation) return Interfaces.Integer_32 is
   begin
      case Direction is
         when Next_Around_Origin          =>
            return C_API.Subdiv2D_Next_Around_Org;

         when Next_Around_Destination     =>
            return C_API.Subdiv2D_Next_Around_Dst;

         when Previous_Around_Origin      =>
            return C_API.Subdiv2D_Prev_Around_Org;

         when Previous_Around_Destination =>
            return C_API.Subdiv2D_Prev_Around_Dst;

         when Next_Around_Left            =>
            return C_API.Subdiv2D_Next_Around_Left;

         when Next_Around_Right           =>
            return C_API.Subdiv2D_Next_Around_Right;

         when Previous_Around_Left        =>
            return C_API.Subdiv2D_Prev_Around_Left;

         when Previous_Around_Right       =>
            return C_API.Subdiv2D_Prev_Around_Right;
      end case;
   end To_C_Navigation;

   function To_C_Rotation
     (Rotation : Edge_Rotation) return Interfaces.Integer_32 is
   begin
      case Rotation is
         when Same_Edge             =>
            return C_API.Subdiv2D_Rotate_Same;

         when Rotated_Edge          =>
            return C_API.Subdiv2D_Rotate_Rotated;

         when Reversed_Edge         =>
            return C_API.Subdiv2D_Rotate_Reversed;

         when Reversed_Rotated_Edge =>
            return C_API.Subdiv2D_Rotate_Reversed_Rotated;
      end case;
   end To_C_Rotation;

   function Navigate
     (Object : Subdivision; Edge : Edge_Id; Direction : Edge_Navigation)
      return Edge_Id
   is
      Operation : constant String := "Subdiv2D.Navigate";
      Result    : aliased Interfaces.Integer_32 := 0;
      Status    : C_API.Status;
   begin
      Status :=
        C_API.Subdiv2D_Get_Edge
          (Native_Handle (Object, Operation),
           Checked_Edge (Edge, Operation),
           To_C_Navigation (Direction),
           Result'Access);
      Raise_On_Error (Status, Operation);
      return To_Edge_Id (Result, Operation);
   end Navigate;

   function Next_Edge (Object : Subdivision; Edge : Edge_Id) return Edge_Id is
      Operation : constant String := "Subdiv2D.Next_Edge";
      Result    : aliased Interfaces.Integer_32 := 0;
      Status    : C_API.Status;
   begin
      Status :=
        C_API.Subdiv2D_Next_Edge
          (Native_Handle (Object, Operation),
           Checked_Edge (Edge, Operation),
           Result'Access);
      Raise_On_Error (Status, Operation);
      return To_Edge_Id (Result, Operation);
   end Next_Edge;

   function Rotate
     (Object : Subdivision; Edge : Edge_Id; Rotation : Edge_Rotation)
      return Edge_Id
   is
      Operation : constant String := "Subdiv2D.Rotate";
      Result    : aliased Interfaces.Integer_32 := 0;
      Status    : C_API.Status;
   begin
      Status :=
        C_API.Subdiv2D_Rotate_Edge
          (Native_Handle (Object, Operation),
           Checked_Edge (Edge, Operation),
           To_C_Rotation (Rotation),
           Result'Access);
      Raise_On_Error (Status, Operation);
      return To_Edge_Id (Result, Operation);
   end Rotate;

   function Symmetric_Edge
     (Object : Subdivision; Edge : Edge_Id) return Edge_Id
   is
      Operation : constant String := "Subdiv2D.Symmetric_Edge";
      Result    : aliased Interfaces.Integer_32 := 0;
      Status    : C_API.Status;
   begin
      Status :=
        C_API.Subdiv2D_Sym_Edge
          (Native_Handle (Object, Operation),
           Checked_Edge (Edge, Operation),
           Result'Access);
      Raise_On_Error (Status, Operation);
      return To_Edge_Id (Result, Operation);
   end Symmetric_Edge;

   --  Converts an edge endpoint, which is No_Vertex for a dual edge whose
   --  Voronoi vertex has not been computed.
   function To_Endpoint
     (Value : Interfaces.Integer_32; Operation : String) return Vertex_Id is
   begin
      if Value < 0 then
         Raise_Error
           (Operation & " failed: OpenCV returned an invalid vertex");
      end if;
      return Vertex_Id (Value);
   end To_Endpoint;

   function Origin (Object : Subdivision; Edge : Edge_Id) return Vertex_Id is
      Operation : constant String := "Subdiv2D.Origin";
      Result    : aliased Interfaces.Integer_32 := 0;
      Status    : C_API.Status;
   begin
      Status :=
        C_API.Subdiv2D_Edge_Org
          (Native_Handle (Object, Operation),
           Checked_Edge (Edge, Operation),
           Result'Access);
      Raise_On_Error (Status, Operation);
      return To_Endpoint (Result, Operation);
   end Origin;

   function Destination (Object : Subdivision; Edge : Edge_Id) return Vertex_Id
   is
      Operation : constant String := "Subdiv2D.Destination";
      Result    : aliased Interfaces.Integer_32 := 0;
      Status    : C_API.Status;
   begin
      Status :=
        C_API.Subdiv2D_Edge_Dst
          (Native_Handle (Object, Operation),
           Checked_Edge (Edge, Operation),
           Result'Access);
      Raise_On_Error (Status, Operation);
      return To_Endpoint (Result, Operation);
   end Destination;

   type Vertex_Slot is record
      Point      : OpenCV.Float32_Point;
      First_Edge : Interfaces.Integer_32;
   end record;

   --  Reads the native vertex slot of Vertex, which must be an occupied slot.
   function Read_Vertex
     (Object : Subdivision; Vertex : Vertex_Id; Operation : String)
      return Vertex_Slot
   is
      Position : aliased C_API.Point_F32 := (X => 0.0, Y => 0.0);
      First    : aliased Interfaces.Integer_32 := 0;
      Kind     : aliased Interfaces.Integer_32 := 0;
      Status   : C_API.Status;
   begin
      if Vertex = No_Vertex then
         Raise_Error (Operation & " requires a vertex, not No_Vertex");
      end if;
      Status :=
        C_API.Subdiv2D_Get_Vertex
          (Native_Handle (Object, Operation),
           Interfaces.Integer_32 (Vertex),
           Position'Access,
           First'Access,
           Kind'Access);
      Raise_On_Error (Status, Operation);
      if Kind /= C_API.Subdiv2D_Vertex_Delaunay
        and then Kind /= C_API.Subdiv2D_Vertex_Voronoi
      then
         Raise_Error (Operation & " failed: Vertex denotes a free slot");
      end if;
      if First < 0 then
         Raise_Error (Operation & " failed: OpenCV returned an invalid edge");
      end if;
      return
        (Point      => To_Public_Point (Position.X, Position.Y),
         First_Edge => First);
   end Read_Vertex;

   function Vertex_Point
     (Object : Subdivision; Vertex : Vertex_Id) return OpenCV.Float32_Point is
   begin
      return Read_Vertex (Object, Vertex, "Subdiv2D.Vertex_Point").Point;
   end Vertex_Point;

   function First_Edge
     (Object : Subdivision; Vertex : Vertex_Id) return Edge_Id is
   begin
      return
        Edge_Id
          (Read_Vertex (Object, Vertex, "Subdiv2D.First_Edge").First_Edge);
   end First_Edge;

   overriding
   procedure Finalize (Object : in out Subdivision) is
   begin
      if Object.Handle /= null then
         C_API.Subdiv2D_Destroy (Object.Handle);
         Object.Handle := null;
      end if;
      Object.Has_Bounds := False;
   end Finalize;

end OpenCV.Geometry.Subdiv2D;
