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

   function Native_Descriptor (Bounds : OpenCV.Rect) return Float32_Rectangle
   is
   begin
      return
        (X      => OpenCV.Float32_Value (Bounds.X),
         Y      => OpenCV.Float32_Value (Bounds.Y),
         Width  => OpenCV.Float32_Value (Bounds.Width),
         Height => OpenCV.Float32_Value (Bounds.Height));
   end Native_Descriptor;

   --  Model precisely the native stored binary32 expressions, not a wider
   --  mathematical interval. Machine forces binary32 rounding even where an
   --  Ada implementation permits excess intermediate precision. Overflow is
   --  inspected as a non-finite result and translated to OpenCV_Error.
   procedure Validate_Native_Bounds
     (Bounds : Float32_Rectangle; Factor : OpenCV.Float32_Value)
   is
      pragma Suppress (Validity_Check);
      pragma Suppress (Overflow_Check);
      use type OpenCV.Float32_Value;
      Big, Right, Bottom : OpenCV.Float32_Value;
   begin
      if not Is_Finite (Bounds.X)
        or else not Is_Finite (Bounds.Y)
        or else not Is_Finite (Bounds.Width)
        or else not Is_Finite (Bounds.Height)
      then
         Raise_Error ("Subdiv2D.Reset requires finite bounds fields");
      end if;
      if Bounds.Width <= 0.0 or else Bounds.Height <= 0.0 then
         Raise_Error
           ("Subdiv2D.Reset requires a positive Bounds width and height");
      end if;

      Big :=
        OpenCV.Float32_Value'Machine
          (Factor * OpenCV.Float32_Value'Max (Bounds.Width, Bounds.Height));
      if not Is_Finite (Big) or else Big <= 0.0 then
         Raise_Error ("Subdiv2D.Reset super-triangle scale must be finite");
      end if;
      Right := OpenCV.Float32_Value'Machine (Bounds.X + Bounds.Width);
      Bottom := OpenCV.Float32_Value'Machine (Bounds.Y + Bounds.Height);
      if not Is_Finite (Right) or else not Is_Finite (Bottom) then
         Raise_Error ("Subdiv2D.Reset upper bounds must remain finite");
      end if;
      if Right <= Bounds.X or else Bottom <= Bounds.Y then
         Raise_Error
           ("Subdiv2D.Reset bounds must advance in binary32 arithmetic");
      end if;
      if not Is_Finite (OpenCV.Float32_Value'Machine (Bounds.X + Big))
        or else not Is_Finite (OpenCV.Float32_Value'Machine (Bounds.Y + Big))
        or else not Is_Finite (OpenCV.Float32_Value'Machine (Bounds.X - Big))
        or else not Is_Finite (OpenCV.Float32_Value'Machine (Bounds.Y - Big))
      then
         Raise_Error
           ("Subdiv2D.Reset super-triangle coordinates must remain finite");
      end if;
   --  Positive effective extents and Factor >= 3 ensure X/Y + Big
   --  advance and X/Y - Big retreat (including at binade boundaries).
   --  Thus A is strictly right, B strictly below, C strictly left/above
   --  the origin. Their exact determinant is positive; no separate
   --  distinctness or arbitrary coordinate-size restriction is needed.
   end Validate_Native_Bounds;

   function Integer_Bounds_Factor return OpenCV.Float32_Value is
   begin
      if C_API.OpenCV_Major_Version = 4
        and then C_API.OpenCV_Minor_Version < 12
      then
         return 3.0;
      end if;
      return 6.0;
   end Integer_Bounds_Factor;

   function To_C_Rect (Bounds : Float32_Rectangle) return C_API.Rect_F32 is
   begin
      return
        (X      => Interfaces.C.C_float (Bounds.X),
         Y      => Interfaces.C.C_float (Bounds.Y),
         Width  => Interfaces.C.C_float (Bounds.Width),
         Height => Interfaces.C.C_float (Bounds.Height));
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
      Descriptor    : constant Float32_Rectangle := Native_Descriptor (Bounds);
      Status        : C_API.Status;
   begin
      Validate_Native_Bounds (Descriptor, Integer_Bounds_Factor);

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
      Object.Native_Bounds := Descriptor;
      Object.Bounds_Mode := Integer_Bounds;
   end Reset;

   function Create (Bounds : Float32_Rectangle) return Subdivision is
      pragma Suppress (Validity_Check);
   begin
      return Result : Subdivision do
         Reset (Result, Bounds);
      end return;
   end Create;

   procedure Reset (Object : in out Subdivision; Bounds : Float32_Rectangle) is
      pragma Suppress (Validity_Check);
      Native_Bounds : aliased C_API.Rect_F32;
      Status        : C_API.Status;
   begin
      if not Is_Natively_Supported (Float32_Subdivision_Bounds_Feature) then
         Raise_Error ("Subdiv2D Float32 bounds require OpenCV 4.13 or newer");
      end if;
      Validate_Native_Bounds (Bounds, 6.0);
      Native_Bounds := To_C_Rect (Bounds);
      if Object.Handle = null then
         declare
            Handle : aliased C_API.Subdiv2D_Handle := null;
         begin
            Status :=
              C_API.Subdiv2D_Create_F32 (Native_Bounds'Access, Handle'Access);
            Object.Handle := Handle;
            Raise_On_Error (Status, "Subdiv2D.Reset");
         end;
      else
         Status :=
           C_API.Subdiv2D_Init_Delaunay_F32
             (Object.Handle, Native_Bounds'Access);
         Raise_On_Error (Status, "Subdiv2D.Reset");
      end if;
      Object.Native_Bounds := Bounds;
      Object.Bounds_Mode := Float32_Bounds;
   end Reset;

   function Is_Ready (Object : Subdivision) return Boolean is
   begin
      return
        Object.Handle /= null
        and then C_API.Subdiv2D_Is_Usable (Object.Handle) = 1;
   end Is_Ready;

   function Bounds (Object : Subdivision) return OpenCV.Rect is
   begin
      if Object.Bounds_Mode = No_Bounds then
         Raise_Error
           ("Subdiv2D.Bounds requires a subdivision initialized by Create or "
            & "Reset");
      end if;
      if Object.Bounds_Mode = Float32_Bounds then
         Raise_Error
           ("Subdiv2D.Bounds: subdivision was initialized with Float32 bounds"
            & "; use Bounds_Float32");
      end if;
      return Object.Bounds;
   end Bounds;

   function Bounds_Float32 (Object : Subdivision) return Float32_Rectangle is
   begin
      if Object.Bounds_Mode = No_Bounds then
         Raise_Error
           ("Subdiv2D.Bounds_Float32 requires a successful Create or Reset");
      end if;
      return Object.Native_Bounds;
   end Bounds_Float32;

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

   function Facet_Points
     (Diagram : Voronoi_Diagram; Index : Positive) return Float32_Point_Array
   is
      Facet : constant Voronoi_Facet := Diagram.Facets (Index);
      Slice : Float32_Point_Array renames
        Diagram.Points (Facet.First .. Facet.Last);
   begin
      return
         Result : constant Float32_Point_Array (1 .. Slice'Length) := Slice;
   end Facet_Points;

   --  Rejects a listed site that is not an inserted point's vertex. The shim
   --  rejects identifiers beyond native storage.
   procedure Check_Site
     (Object : Subdivision; Site : Vertex_Id; Operation : String)
   is
      Position : aliased C_API.Point_F32 := (X => 0.0, Y => 0.0);
      First    : aliased Interfaces.Integer_32 := 0;
      Kind     : aliased Interfaces.Integer_32 := 0;
      Status   : C_API.Status;
   begin
      if Site < 4 then
         Raise_Error
           (Operation
            & " requires inserted-point vertices, not No_Vertex or a"
            & " super-triangle vertex");
      end if;
      Status :=
        C_API.Subdiv2D_Get_Vertex
          (Native_Handle (Object, Operation),
           Interfaces.Integer_32 (Site),
           Position'Access,
           First'Access,
           Kind'Access);
      Raise_On_Error (Status, Operation);
      if Kind /= C_API.Subdiv2D_Vertex_Delaunay then
         Raise_Error
           (Operation
            & " requires inserted-point vertices, not a free slot or a"
            & " Voronoi vertex");
      end if;
   end Check_Site;

   --  Reads the Voronoi facets of every inserted point, when Every, or else
   --  of Sites, which the caller has checked. A first native call sizes the
   --  C buffers, which live on the heap; the result is built in place.
   function Read_Voronoi
     (Object    : Subdivision;
      Every     : Boolean;
      Sites     : Vertex_Id_Array;
      Operation : String) return Voronoi_Diagram
   is
      type Vertex_List_Access is access C_API.Int32_Array;
      type Facet_Buffer_Access is access C_API.C_Voronoi_Facet_Array;
      type Point_Buffer_Access is access C_API.Point_F32_Array;

      procedure Free is new
        Ada.Unchecked_Deallocation (C_API.Int32_Array, Vertex_List_Access);
      procedure Free is new
        Ada.Unchecked_Deallocation
          (C_API.C_Voronoi_Facet_Array,
           Facet_Buffer_Access);
      procedure Free is new
        Ada.Unchecked_Deallocation
          (C_API.Point_F32_Array,
           Point_Buffer_Access);

      Handle    : constant C_API.Subdiv2D_Handle :=
        Native_Handle (Object, Operation);
      Selection : constant Interfaces.Integer_32 :=
        (if Every
         then C_API.Subdiv2D_Voronoi_Select_All
         else C_API.Subdiv2D_Voronoi_Select_Listed);
      Vertices  : Vertex_List_Access;
      Facets    : Facet_Buffer_Access;
      Points    : Point_Buffer_Access;

      procedure Invalid_Result
      with No_Return;

      procedure Invalid_Result is
      begin
         Raise_Error (Operation & " failed: invalid native Voronoi facets");
      end Invalid_Result;

      function Read
        (List : access constant Interfaces.Integer_32; Count : Natural)
         return Voronoi_Diagram
      is
         Facet_Count : aliased Interfaces.Integer_32 := 0;
         Point_Count : aliased Interfaces.Integer_32 := 0;
         Status      : C_API.Status;
      begin
         Status :=
           C_API.Subdiv2D_Voronoi_Facet_Counts
             (Handle,
              Selection,
              List,
              Interfaces.Integer_32 (Count),
              Facet_Count'Access,
              Point_Count'Access);
         Raise_On_Error (Status, Operation);
         --  Every facet has at least one point, and every checked site
         --  produces exactly one facet.
         if Facet_Count < 0
           or else Point_Count < Facet_Count
           or else (not Every and then Natural (Facet_Count) /= Count)
         then
            Invalid_Result;
         end if;
         if Facet_Count = 0 then
            if Point_Count /= 0 then
               Invalid_Result;
            end if;
            return Empty : Voronoi_Diagram (0, 0);
         end if;

         Facets :=
           new C_API.C_Voronoi_Facet_Array (0 .. Natural (Facet_Count) - 1);
         Points := new C_API.Point_F32_Array (0 .. Natural (Point_Count) - 1);
         declare
            Expected_Facets : constant Interfaces.Integer_32 := Facet_Count;
            Expected_Points : constant Interfaces.Integer_32 := Point_Count;
         begin
            Status :=
              C_API.Subdiv2D_Get_Voronoi_Facets
                (Handle,
                 Selection,
                 List,
                 Interfaces.Integer_32 (Count),
                 Facets (Facets'First)'Access,
                 Expected_Facets,
                 Points (Points'First)'Access,
                 Expected_Points,
                 Facet_Count'Access,
                 Point_Count'Access);
            Raise_On_Error (Status, Operation);
            --  Nothing modified Object between the two calls, so OpenCV
            --  reports the same facets.
            if Facet_Count /= Expected_Facets
              or else Point_Count /= Expected_Points
            then
               Invalid_Result;
            end if;
         end;

         return
            Result :
              Voronoi_Diagram (Natural (Facet_Count), Natural (Point_Count))
         do
            declare
               Next_Point : Interfaces.Integer_32 := 0;
               Last_Site  : Interfaces.Integer_32 := 3;
            begin
               for Index in Result.Facets'Range loop
                  declare
                     Native : C_API.C_Voronoi_Facet renames Facets (Index - 1);
                  begin
                     if Native.First_Point /= Next_Point
                       or else Native.Point_Count < 1
                       or else Native.Point_Count > Point_Count - Next_Point
                     then
                        Invalid_Result;
                     end if;
                     --  Every inserted point once, in increasing order, or
                     --  exactly the checked sites.
                     if Every then
                        if Native.Site <= Last_Site then
                           Invalid_Result;
                        end if;
                        Last_Site := Native.Site;
                     elsif Native.Site
                       /= Interfaces.Integer_32
                            (Sites (Sites'First + (Index - 1)))
                     then
                        Invalid_Result;
                     end if;
                     if Native.Complete /= 0 and then Native.Complete /= 1 then
                        Invalid_Result;
                     end if;
                     Result.Facets (Index) :=
                       (Site       => Vertex_Id (Native.Site),
                        Site_Point =>
                          To_Public_Point (Native.Center_X, Native.Center_Y),
                        First      => Natural (Native.First_Point) + 1,
                        Last       =>
                          Natural (Native.First_Point + Native.Point_Count),
                        Complete   => Native.Complete = 1);
                     Next_Point := Next_Point + Native.Point_Count;
                  end;
               end loop;
               if Next_Point /= Point_Count then
                  Invalid_Result;
               end if;
            end;
            for Index in Result.Points'Range loop
               Result.Points (Index) :=
                 To_Public_Point (Points (Index - 1).X, Points (Index - 1).Y);
            end loop;
            Free (Facets);
            Free (Points);
         end return;
      end Read;
   begin
      if Every or else Sites'Length = 0 then
         return Read (null, 0);
      end if;

      Vertices := new C_API.Int32_Array (0 .. Sites'Length - 1);
      for Offset in Vertices'Range loop
         Vertices (Offset) :=
           Interfaces.Integer_32 (Sites (Sites'First + Offset));
      end loop;
      return
         Result : constant Voronoi_Diagram :=
           Read (Vertices (Vertices'First)'Access, Sites'Length)
      do
         Free (Vertices);
      end return;
   exception
      when others =>
         Free (Vertices);
         Free (Facets);
         Free (Points);
         raise;
   end Read_Voronoi;

   function Voronoi_Facets (Object : in out Subdivision) return Voronoi_Diagram
   is
   begin
      return
        Read_Voronoi
          (Object,
           Every     => True,
           Sites     => (1 .. 0 => No_Vertex),
           Operation => "Subdiv2D.Voronoi_Facets");
   end Voronoi_Facets;

   function Voronoi_Facets
     (Object : in out Subdivision; Sites : Vertex_Id_Array)
      return Voronoi_Diagram
   is
      Operation : constant String := "Subdiv2D.Voronoi_Facets";
   begin
      for Site of Sites loop
         Check_Site (Object, Site, Operation);
      end loop;
      return
        Read_Voronoi
          (Object, Every => False, Sites => Sites, Operation => Operation);
   end Voronoi_Facets;

   overriding
   procedure Finalize (Object : in out Subdivision) is
   begin
      if Object.Handle /= null then
         C_API.Subdiv2D_Destroy (Object.Handle);
         Object.Handle := null;
      end if;
      Object.Bounds_Mode := No_Bounds;
   end Finalize;

end OpenCV.Geometry.Subdiv2D;
