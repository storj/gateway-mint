#!/bin/bash -e
#
#  Mint (C) 2017 Minio, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

MINIO_GO_VERSION="v7.0.95"

test_run_dir="$MINT_RUN_CORE_DIR/minio-go"
curl -sL -o "${test_run_dir}/main.go" "https://raw.githubusercontent.com/minio/minio-go/${MINIO_GO_VERSION}/functional_tests.go"
(cd "$test_run_dir" && go mod tidy -compat=1.21 && CGO_ENABLED=0 go build --ldflags "-s -w" -o minio-go main.go)
