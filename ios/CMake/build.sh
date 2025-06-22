#!/bin/bash

# Homebrew installs at different locations for Intel (/usr/local) and Apple Silicon (/opt/homebrew).
export PATH="$PATH:/opt/homebrew/bin"

AUI_CMAKE_BINARY_DIR=$DERIVED_FILES_DIR/build
echo "CMake build dir: $AUI_CMAKE_BINARY_DIR"
cmake --build "$AUI_CMAKE_BINARY_DIR"
