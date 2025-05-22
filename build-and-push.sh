#!/usr/bin/env bash

DOCKER_USER=kirbownz
DOCKER_IMAGE_NAME=epic-prefill-docker

ARGUMENT_VERSION=${1:-"latest"}

LATEST_RELEASE_LINK=$(curl -s https://api.github.com/repos/tpill90/epic-lancache-prefill/releases/latest | grep 'browser_' | cut -d\" -f4 | grep 'linux-x64')
LATEST_VERSION=$(echo ${LATEST_RELEASE_LINK} | sed 's/.*-\(.*\)-.*-.*/\1/')

BUILD_VERSION=$([ "${ARGUMENT_VERSION}" == "latest" ] && echo ${LATEST_VERSION} || echo ${ARGUMENT_VERSION})

cat <<EOF
Argument version: ${ARGUMENT_VERSION}
Latest version:   ${LATEST_VERSION}
Building version: ${BUILD_VERSION}
EOF

docker build . --build-arg PREFILL_VERSION=${BUILD_VERSION} -t ${DOCKER_USER}/${DOCKER_IMAGE_NAME}:latest &&
docker image tag ${DOCKER_USER}/${DOCKER_IMAGE_NAME}:latest ${DOCKER_USER}/${DOCKER_IMAGE_NAME}:${BUILD_VERSION} &&

docker push ${DOCKER_USER}/${DOCKER_IMAGE_NAME}:${BUILD_VERSION} &&
docker push ${DOCKER_USER}/${DOCKER_IMAGE_NAME}:latest

