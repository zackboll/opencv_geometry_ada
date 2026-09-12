# Geometry architecture

This crate implements only OpenCV.Geometry and depends only on opencv_core.
The public Contour is a subtype of Core.Point_Array, owned by Ada.
Do not introduce an Ada Imgproc dependency or Mat/Find_Contours operations.

Layering: thick Ada -> thin Ada C interop -> C ABI -> C++ -> OpenCV.
Select headers by CV_VERSION_MAJOR and native libraries by pkg-config version:
OpenCV 4 uses imgproc; OpenCV 5 and later use geometry. Keep the Ada API stable.

Pack X/Y explicitly into signed 32-bit C records in array iteration order.
Check the count range; never reinterpret public point storage or index an
empty array. Copy all 24 moments explicitly across both boundaries.

The shim does not use Core's module bridge or Core shim: no Mat handles cross
this boundary. Core remains the owner of public point and numeric types.

Ada owns public semantic policy. C++ validates ABI representations, pointer /
count safety and output initialization, and contains every exception.
Native failures raise OpenCV.OpenCV_Error through a private helper.
No STL, C++ exceptions or native objects cross the C ABI.
