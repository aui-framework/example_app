#!/bin/bash

# Homebrew installs at different locations for Intel (/usr/local) and Apple Silicon (/opt/homebrew).
export PATH="$PATH:/opt/homebrew/bin"

# Uncomment this to print environment variables available from within this script and CMake.
# env

AUI_CMAKE_BINARY_DIR=$DERIVED_FILES_DIR/build
echo "CMake build dir: $AUI_CMAKE_BINARY_DIR"

# customize how does Xcode invokes CMake here.
cmake -GNinja -DCMAKE_TOOLCHAIN_FILE=$SRCROOT/CMake/Toolchains/arm64-ios.cmake -S $SRCROOT/.. -B "$AUI_CMAKE_BINARY_DIR" -DAUIB_AUI_AS=TRUE
