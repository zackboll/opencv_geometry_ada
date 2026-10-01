#!/bin/sh

# Builds and runs the native C++ tests in tests/native against the OpenCV
# recorded by scripts/configure_opencv.sh. They exercise shim behavior that
# Ada tests cannot reach, such as allocation failures inside OpenCV.
#
# Run after `alr -n build`, which writes config/opencv_geometry_install.gpr.
# Linux only: the tests replace the global C++ allocation functions and link
# directly against the native OpenCV libraries with the system g++.

set -eu

config=config/opencv_geometry_install.gpr

if [ "$(uname -s)" != "Linux" ]; then
    echo "error: native tests are supported on Linux only" >&2
    exit 1
fi

if [ ! -f "$config" ]; then
    echo "error: $config is missing; run 'alr -n build' first" >&2
    exit 1
fi

config_value() {
    sed -n "s/^ *$1[ :A-Za-z_]*:= \"\\(.*\\)\";\$/\\1/p" "$config" | head -n 1
}

include_switch=$(config_value Include_Switch)
library_switch=$(config_value Library_Search_Switch)
geometry_library=$(config_value OpenCV_Geometry_Link_Option)
core_library=$(config_value OpenCV_Core_Link_Option)
opencv_version=$(config_value OpenCV_Version)

output_dir=obj/native
mkdir -p "$output_dir"

echo "Native tests: OpenCV $opencv_version"

for source in tests/native/*.cpp
do
    program="$output_dir/$(basename "$source" .cpp)"
    echo "Building $source"
    g++ -std=c++17 -Wall -Wextra -Wpedantic -Werror -O1 -g \
        -fsanitize=address,undefined -fno-omit-frame-pointer \
        "$include_switch" -o "$program" "$source" \
        "$library_switch" "$geometry_library" "$core_library"
    echo "Running $program"
    "$program"
done
