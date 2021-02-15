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

# Flags
PYTHON_VERSIONS=3.6 # Options 3.6 (default), 3.7, 3.8
CLEAN=false # Set to true to run bazel clean.
OUTPUT_DIR=/tmp/launchpad/dist/
PYTHON_TESTS=true

ABI=cp36
PIP_PKG_EXTRA_ARGS="" # Extra args passed to `build_pip_package`.

if [[ $# -lt 1 ]] ; then
  echo "Usage:"
  echo "--release [Indicates this is a release build. Otherwise nightly.]"
  echo "--python [3.6(default)|3.7|3.8]"
  echo "--clean  [true to run bazel clean]"
  echo "--tf_dep_override  [Required tensorflow version to pass to setup.py."
  echo "                    Examples: tensorflow==2.3.0rc0  or tensorflow>=2.3.0]"
  echo "--python_tests  [true (default) to run python tests.]"
  echo "--output_dir  [location to copy .whl file.]"
  exit 1
fi

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
      --python_tests)
      PYTHON_TESTS="$2"
      shift
      ;;
      --output_dir)
      OUTPUT_DIR="$2"
      shift
      ;;
      --tf_dep_override)
      # Setup.py is told this is the tensorflow dependency.
      PIP_PKG_EXTRA_ARGS="${PIP_PKG_EXTRA_ARGS} --tf-version ${2}"
      shift
      ;;
    *)
      echo "Unknown flag: $key"
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

  if [ "$python_version" = "3.6" ]; then
    export PYTHON_BIN_PATH=/usr/bin/python3.6 && export PYTHON_LIB_PATH=/usr/local/lib/python3.6/dist-packages
  elif [ "$python_version" = "3.7" ]; then
    export PYTHON_BIN_PATH=/usr/local/bin/python3.7 && export PYTHON_LIB_PATH=/usr/local/lib/python3.7/dist-packages
    ABI=cp37
  elif [ "$python_version" = "3.8" ]; then
    export PYTHON_BIN_PATH=/usr/bin/python3.8 && export PYTHON_LIB_PATH=/usr/local/lib/python3.8/dist-packages
    ABI=cp38
  else
    echo "Error unknown --python. Only [3.6|3.7|3.8]"
    exit 1
  fi

  # Configures Bazel environment for selected Python version.
  $PYTHON_BIN_PATH configure.py

  # Build Launchpad and run all bazel Python tests. All other tests are executed
  # later.
  bazel build -c opt --copt=-mavx --test_output=errors //...

  # Builds Launchpad and creates the wheel package.
  /tmp/launchpad/launchpad/pip_package/build_pip_package.sh --dst $OUTPUT_DIR $PIP_PKG_EXTRA_ARGS

done
