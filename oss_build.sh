#!/bin/bash
# Copyright 2020 DeepMind Technologies Limited. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Designed to work with ./docker/build.dockerfile to build Launchpad.

# Exit if any process returns non-zero status.
set -e
set -o pipefail
cd "$(dirname "$0")"

# Flags
PYTHON_VERSIONS=3.9 # Options 3.7, 3.8, 3.9, 3.10
CLEAN=false # Set to true to run bazel clean.
OUTPUT_DIR=/tmp/launchpad/dist
INSTALL=true # Should the built package be installed.

PIP_PKG_EXTRA_ARGS="" # Extra args passed to `build_pip_package`.

while [[ $# -gt -0 ]]; do
  key="$1"
  case $key in
      --release)
      PIP_PKG_EXTRA_ARGS="${PIP_PKG_EXTRA_ARGS} --release" # Indicates this is a release build.
      ;;
      --python)
      PYTHON_VERSIONS="$2" # Python versions to build against.
      shift
      ;;
      --clean)
      CLEAN="$2" # `true` to run bazel clean. False otherwise.
      shift
      ;;
      --install)
      INSTALL="$2" # `true` to install built package. False otherwise.
      shift
      ;;
      --output_dir)
      OUTPUT_DIR="$2"
      shift
      ;;
    *)
      echo "Unknown flag: $key"
      echo "Usage:"
      echo "--release [Indicates this is a release build. Otherwise nightly.]"
      echo "--python  [3.7|3.8(default)|3.9]"
      echo "--clean   [true to run bazel clean]"
      echo "--install [true to install built package]"
      echo "--output_dir  [location to copy .whl file.]"
      exit 1
      ;;
  esac
  shift # past argument or value
done

for python_version in $PYTHON_VERSIONS; do

  # Cleans the environment.
  if [ "$CLEAN" = "true" ]; then
    bazel clean
  fi

  if [ "$python_version" = "3.7" ]; then
    ABI=cp37
  elif [ "$python_version" = "3.8" ]; then
    ABI=cp38
  elif [ "$python_version" = "3.9" ]; then
    ABI=cp39
  elif [ "$python_version" = "3.10" ]; then
    ABI=cp310
  else
    echo "Error unknown --python. Only [3.7|3.8|3.9|3.10]"
    exit 1
  fi

  export PYTHON_BIN_PATH=`which python${python_version}`
  export PYTHON_LIB_PATH=`${PYTHON_BIN_PATH} -c 'import site; print(site.getsitepackages()[0])'`

  # Configures Bazel environment for selected Python version.
  $PYTHON_BIN_PATH configure.py

  # Build Launchpad and run all bazel Python tests. All other tests are executed
  # later.
  # bazel build -c opt --copt=-mavx --config=manylinux2014 --test_output=errors //...
  bazel build -c opt --test_output=errors //...  --verbose_failures --sandbox_debug --subcommands=pretty_print

  # Builds Launchpad and creates the wheel package.
  $(pwd)/launchpad/pip_package/build_pip_package.sh --dst $OUTPUT_DIR/fresh $PIP_PKG_EXTRA_ARGS

  # Install built package.
  if [ "$INSTALL" = "true" ]; then
    $PYTHON_BIN_PATH -m pip install --upgrade $OUTPUT_DIR/fresh/* --force-reinstall
  fi

  chmod 666 $OUTPUT_DIR/fresh/*
  mv $OUTPUT_DIR/fresh/* $OUTPUT_DIR/
  rm -r $OUTPUT_DIR/fresh

done
