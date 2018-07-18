#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

set -e

usage() {
  cat >&2 << EOF

Usage:  generate-all.sh

Execute generate-license-and-notice.sh to generate LICENSE and NOTICE files for all Brooklyn projects.

EOF
}

while [ ! -z "$*" ] ; do

  if [ "$1" == "--help" ]; then usage ; exit 0; fi

  usage
  echo Unexpected argument: $1
  exit 1 

done


REF_DIR=$(pushd $(dirname $0) > /dev/null ; pwd -P ; popd > /dev/null)
PARTS_DIR=$REF_DIR/parts
ROOT_DIR=$REF_DIR/../../..
MVN_OUTFILE=$REF_DIR/notices.autogenerated

prefix_and_join_array() {
  PREFIX=$2
  JOIN_BEFORE_PREFIX=$1
  JOIN_AFTER_PREFIX=$3
  echo -n ${PREFIX}$4
  shift 4
  while (($#  >= 1)) ; do
    echo -n "${JOIN_BEFORE_PREFIX}${PREFIX}${JOIN_AFTER_PREFIX}$1"
    shift
  done
}

# takes root dir in first arg, then regex expression 
make_for() {
  PROJ=$(cd $1 ; pwd -P)
  OUT=${PROJ}/$2
  MODE=$3
  SEARCH_ROOT=$4
  if [ -z "$SEARCH_ROOT" ] ; then SEARCH_ROOT=$PROJ ; fi

  echo Generating for $PROJ mode $MODE to $2...
  echo ""
  
  pushd $PROJ > /dev/null
  
  if [ "$MODE" == "binary-additional" ] ; then

    $REF_DIR/generate-license-and-notice.sh \
      -o $OUT \
      --license $PARTS_DIR/license-top \
      --license $PARTS_DIR/license-deps \
      --notice $PARTS_DIR/notice-top --notice-compute-with-flags "
        -DextrasFiles=$(prefix_and_join_array "" ":" "" $(find $SEARCH_ROOT -name "license-inclusions-source-*"))
        -DonlyExtras=true" \
      --notice $PARTS_DIR/notice-additional --notice-compute-with-flags "
        -DextrasFiles=$(prefix_and_join_array "" ":" "" $(find $SEARCH_ROOT -name "license-inclusions-binary-*"))" \
      --libraries ${REF_DIR} ${SEARCH_ROOT}
    
  elif [ "$MODE" == "binary-primary" ] ; then

    $REF_DIR/generate-license-and-notice.sh \
      -o $OUT \
      --license $PARTS_DIR/license-top \
      --license $PARTS_DIR/license-deps \
      --notice $PARTS_DIR/notice-top --notice-compute-with-flags "
        -DextrasFiles=$(prefix_and_join_array "" ":" "" $(find $SEARCH_ROOT -name "license-inclusions-source-*" -or -name "license-inclusions-binary-*"))" \
      --libraries ${REF_DIR} ${SEARCH_ROOT}
      
  elif [ "$MODE" == "binary-omitted" ] ; then

    $REF_DIR/generate-license-and-notice.sh \
      -o $OUT \
      --license $PARTS_DIR/license-top \
      --license $PARTS_DIR/license-deps \
      --notice $PARTS_DIR/notice-top --notice-compute-with-flags "
        -DextrasFiles=$(prefix_and_join_array "" ":" "" $(find $SEARCH_ROOT -name "license-inclusions-source-*"))
        -DonlyExtras=true" \
      --libraries ${REF_DIR} ${SEARCH_ROOT}

  else
    echo FAILED - unknown mode $MODE
    exit 1
  fi
  echo ""
  
  popd > /dev/null
}


# build all the projects

# include deps in files pulled in to Go CLI binary builds
make_for $ROOT_DIR/brooklyn-client/cli/ release/license/files binary-primary
make_for $ROOT_DIR/brooklyn-client/cli/ . binary-additional

# Server CLI has embedded JS; gets custom files in sub-project root, also included in JAR
make_for $ROOT_DIR/brooklyn-server/server-cli/ . binary-additional

# UI gets files at root, also included in WAR
make_for $ROOT_DIR/brooklyn-ui/ . binary-additional

# main projects have their binaries included at root
make_for $ROOT_DIR/brooklyn-server/ . binary-additional
make_for $ROOT_DIR/brooklyn-client/ . binary-additional
make_for $ROOT_DIR/brooklyn-library/ . binary-additional
# dist is trickier, just don't mention binaries in the generated items
make_for $ROOT_DIR/brooklyn-dist/ . binary-omitted

# brooklyn-docs skipped
# the docs don't make a build and don't include embedded code so no special license there

# and the binary dists; dist/ project which has biggest deps set, but search in all brooklyn projects
make_for $ROOT_DIR/brooklyn-dist/dist src/main/license/files/ binary-primary $ROOT_DIR
cp $OUT/{NOTICE,LICENSE} $PROJ/../karaf/apache-brooklyn/src/main/resources/

# finally in root project list everything
make_for $ROOT_DIR/brooklyn-dist/dist ../.. binary-additional $ROOT_DIR