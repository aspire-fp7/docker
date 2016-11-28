#!/bin/bash

set -e
set -u

usage() {
  echo "Usage: $0 path/to/target/buildpath"
  exit 1
}

if [ ! $# -eq 1 ]
then
  usage
fi

BUILDPATH=${1}
SRCFILE=`readlink -f ${0}`
SRCDIR=`dirname ${SRCFILE}`

FRAMEWORK_REPO=https://github.com/aspire-fp7/framework
DEMO_REPO=https://github.com/aspire-fp7/actc-demos

if [ ! -d "${BUILDPATH}" ]
then
  echo "Target build path does not exist!"
  usage
fi

echo "Setting up files for a Docker container from ${BUILDPATH}"

full_clean() {
  rm -rf ${BUILDPATH}/files/
  
  if [ -d ${BUILDPATH}/projects/ ]
  then
    echo "Warning! The projects directory already exists at ${BUILDPATH}! Aborting rather than overwriting this directory!"
    exit 1
  fi

  rm -rf ${BUILDPATH}/support

  rm -f ${BUILDPATH}/Dockerfile
  rm -f ${BUILDPATH}/run.sh
 
  mkdir files
}

full_clean

pushd ${BUILDPATH}
cp ${SRCDIR}/Dockerfile .
cp -a ${SRCDIR}/support .
ln -s ${SRCDIR}/run.sh .

git_clone_or_pull_to() {
  REPO=${1}
  DIR=${2}

  if [ -d "${DIR}" ]
  then
    pushd ${DIR}
    git pull
    popd
  else
    git clone ${REPO} ${DIR}
  fi
}

# TODO: toolchains & prebuilts, fetch them here as well?

pushd files

git_clone_or_pull_to ${FRAMEWORK_REPO} framework

pushd framework
git submodule update --init
popd

popd

# A demo project:
echo "Setting up a clean demo project"
mkdir projects
pushd projects
git clone ${DEMO_REPO}
popd

echo "Done setting up files, building container image"

docker build -t aspire .
