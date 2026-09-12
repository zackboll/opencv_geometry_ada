#!/bin/sh

set -eu

shim_build=${1:-}

case "$shim_build" in
    Static_PIC|Relocatable)
        exit 0
        ;;
    External_Relocatable)
        ;;
    *)
        echo "error: unsupported or missing shim build capability: ${shim_build:-<missing>}" >&2
        exit 1
        ;;
esac

if [ "$#" -ne 6 ]; then
    echo "usage: $0 External_Relocatable CXX_DRIVER INCLUDE_DIR LIBRARY_DIR OPENCV_GEOMETRY_LINK_OPTION OPENCV_CORE_LINK_OPTION" >&2
    exit 1
fi

cxx_driver=$2
include_dir=$3
library_dir=$4
opencv_geometry_link_option=$5
opencv_core_link_option=$6
source=cpp/opencv_geometry_shim.cpp
object=obj/shim/external/opencv_geometry_shim.o

case "$cxx_driver" in
    *gnat_native*)
        echo "error: external C++ driver resolved to the GNAT toolchain: $cxx_driver" >&2
        exit 1
        ;;
esac

sysname=$(uname -s)

case "$sysname" in
    Darwin)
        shim_dylib=lib/libopencv_geometry_shim.dylib

        if ! command -v xcrun >/dev/null 2>&1; then
            echo "error: xcrun is required to locate the macOS SDK" >&2
            exit 1
        fi
        cxx_sysroot=$(xcrun --sdk macosx --show-sdk-path)
        if [ -z "$cxx_sysroot" ]; then
            echo "error: could not resolve the macOS SDK path via xcrun --sdk macosx --show-sdk-path" >&2
            exit 1
        fi

        for required in "$cxx_driver" "$source"
        do
            if [ ! -f "$required" ]; then
                echo "error: required Geometry shim build input is missing: $required" >&2
                exit 1
            fi
        done
        for required in "$include_dir" "$library_dir" "$cxx_sysroot"
        do
            if [ ! -d "$required" ]; then
                echo "error: required Geometry shim build directory is missing: $required" >&2
                exit 1
            fi
        done

        mkdir -p lib obj/shim/external
        rm -f "$shim_dylib" "$object"

        echo "Building External_Relocatable OpenCV Geometry shim"
        echo "C++ driver: $cxx_driver"
        echo "OpenCV include: $include_dir"
        echo "OpenCV library: $library_dir"
        echo "OpenCV Geometry link option: $opencv_geometry_link_option"
        echo "OpenCV Core link option: $opencv_core_link_option"
        echo "macOS SDK: $cxx_sysroot"

        # Keep GNAT include/library paths from leaking into Apple clang++.
        env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH \
            -u LIBRARY_PATH -u GCC_EXEC_PREFIX -u COMPILER_PATH \
            "$cxx_driver" -c -std=c++17 -Wall -Wextra -Wpedantic -Werror \
            -Wno-error=c11-extensions \
            -isysroot "$cxx_sysroot" \
            "-I$include_dir" -o "$object" "$source"

        env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH \
            -u LIBRARY_PATH -u GCC_EXEC_PREFIX -u COMPILER_PATH \
            "$cxx_driver" -dynamiclib \
            -isysroot "$cxx_sysroot" \
            -o "$shim_dylib" \
            -install_name "@rpath/libopencv_geometry_shim.dylib" \
            -Wl,-rpath,"$library_dir" \
            "$object" \
            "-L$library_dir" \
            "$opencv_geometry_link_option" \
            "$opencv_core_link_option" \
            -lc++
        ;;

    MINGW*|MSYS*)
        shim_dll=lib/libopencv_geometry_shim.dll
        shim_import_library=lib/libopencv_geometry_shim.dll.a

        mkdir -p lib obj/shim/external
        rm -f "$shim_dll" "$shim_import_library" "$object"

        for required in "$cxx_driver" "$source" "$include_dir" "$library_dir" \
                        "$opencv_geometry_link_option" \
                        "$opencv_core_link_option"
        do
            if [ ! -e "$required" ]; then
                echo "error: required Geometry shim build input is missing: $required" >&2
                exit 1
            fi
        done

        compile_include=$include_dir
        compile_source=$source
        compile_object=$object
        link_object=$object
        link_dll=$shim_dll
        link_import_library=$shim_import_library
        link_opencv_geometry=$opencv_geometry_link_option
        link_opencv_core=$opencv_core_link_option

        # Native MinGW g++.exe accepts MSYS paths inconsistently. Preserve
        # the path conversion used by the validated Core Windows shim build.
        if command -v cygpath >/dev/null 2>&1; then
            compile_include=$(cygpath -m "$include_dir")
            compile_source=$(cygpath -m "$source")
            compile_object=$(cygpath -m "$object")
            link_object=$compile_object
            link_dll=$(cygpath -m "$shim_dll")
            link_import_library=$(cygpath -m "$shim_import_library")
            link_opencv_geometry=$(cygpath -m "$opencv_geometry_link_option")
            link_opencv_core=$(cygpath -m "$opencv_core_link_option")
        fi

        echo "Building External_Relocatable OpenCV Geometry shim"
        echo "C++ driver: $cxx_driver"
        echo "OpenCV include: $include_dir"
        echo "OpenCV Geometry import library: $opencv_geometry_link_option"
        echo "OpenCV Core import library: $opencv_core_link_option"

        env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH \
            -u LIBRARY_PATH -u GCC_EXEC_PREFIX -u COMPILER_PATH \
            "$cxx_driver" -c -std=c++17 -Wall -Wextra -Wpedantic -Werror \
            "-I$compile_include" -o "$compile_object" "$compile_source"

        env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH \
            -u LIBRARY_PATH -u GCC_EXEC_PREFIX -u COMPILER_PATH \
            "$cxx_driver" -shared -o "$link_dll" \
            "-Wl,--out-implib,$link_import_library" \
            "$link_object" "$link_opencv_geometry" "$link_opencv_core"
        ;;

    *)
        echo "error: External_Relocatable Geometry shim is only supported on macOS and Windows" >&2
        exit 1
        ;;
esac
