#!/bin/sh
# Builds llama.cpp as an XCFramework for iOS devices and the Simulator (not stored in git).
# Needs Xcode and CMake (brew install cmake). Takes a few minutes.
set -eu
cd "$(dirname "$0")/.."
TAG="b11577"
SRC="Vendor/llama.cpp-src"
if [ ! -d "$SRC" ]; then
    git clone --depth 1 --branch "$TAG" https://github.com/ggml-org/llama.cpp.git "$SRC"
fi
cd "$SRC"
./build-xcframework.sh ios-sim ios-device
echo "Built $SRC/build-apple/llama.xcframework"
