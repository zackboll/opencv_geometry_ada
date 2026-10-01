with Ada.Exceptions;
with Interfaces;
with Interfaces.C;

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
