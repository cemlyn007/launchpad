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

# Executes Launchpad Python tests.
set +x
set -e

LOCATION=`python3 -c 'import launchpad as lp; print(lp.__path__[0])'`

py_test() {
  echo "===========Running Python tests============"

  for test_file in `find $LOCATION -name '*_test.py' -print`
  do
    echo "####=======Testing ${test_file}=======####"
    python3 "${test_file}"
  done
}

py_test
