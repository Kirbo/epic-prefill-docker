#!/usr/bin/env bash

DOCKER_USER=kirbownz
DOCKER_IMAGE_NAME=epic-prefill-docker
DOCKER_REGISTRY=${CI_REGISTRY:-docker.io}
BINARY_REPOSITORY=${DOCKER_IMAGE_NAME/prefill-docker/lancache-prefill}

ARGUMENT_VERSION=${1:-"latest"}
# FORCE_BUILD=true rebuilds and re-pushes the version even when the registry already has it (e.g. to
# ship a Dockerfile fix before the next upstream release). Set it on a manually run pipeline.
FORCE_BUILD=${FORCE_BUILD:-false}

CURL_OPTS=(-s)
[ -n "${GITHUB_TOKEN}" ] && CURL_OPTS+=(-H "Authorization: token ${GITHUB_TOKEN}")

LATEST_RELEASE_LINK=$(curl "${CURL_OPTS[@]}" "https://api.github.com/repos/tpill90/${BINARY_REPOSITORY}/releases/latest" | grep 'browser_' | cut -d\" -f4 | grep 'linux-x64')
# shellcheck disable=SC2001
LATEST_VERSION=$(echo "${LATEST_RELEASE_LINK}" | sed 's/.*-\(.*\)-.*-.*/\1/')

if [ -z "${LATEST_VERSION}" ] && [ "${ARGUMENT_VERSION}" == "latest" ]; then
    echo "ERROR: Failed to fetch latest version from GitHub API. The API may be rate-limited."
    exit 1
fi

BUILD_VERSION=$([ "${ARGUMENT_VERSION}" == "latest" ] && echo "${LATEST_VERSION}" || echo "${ARGUMENT_VERSION}")

LATEST_DOCKER_IMAGE=$(curl -s "https://registry.hub.docker.com/v2/repositories/${DOCKER_USER}/${DOCKER_IMAGE_NAME}/tags?page_size=100" | jq -r '.results[].name | select(. != "latest")' | head -n 1)

cat <<EOF
Argument version: ${ARGUMENT_VERSION}
Latest version:   ${LATEST_VERSION}
Building version: ${BUILD_VERSION}
Docker version:   ${LATEST_DOCKER_IMAGE}
Force build:      ${FORCE_BUILD}

EOF

if [ "${BUILD_VERSION}" == "${LATEST_DOCKER_IMAGE}" ] && [ "${FORCE_BUILD}" != "true" ]; then
    echo "The Docker image is already up to date with version ${BUILD_VERSION}. Exiting."
    exit 0
elif [ "${BUILD_VERSION}" == "${LATEST_DOCKER_IMAGE}" ]; then
    echo "FORCE_BUILD=true: rebuilding and re-pushing Docker image version ${BUILD_VERSION}..."
else
    echo "Building and pushing Docker image version ${BUILD_VERSION}..."
fi

docker buildx build \
    --build-arg "PREFILL_VERSION=${BUILD_VERSION}" \
    --push \
    --provenance=true \
    --sbom=true \
    --platform linux/amd64,linux/arm64 \
    -t "${DOCKER_REGISTRY}/${DOCKER_USER}/${DOCKER_IMAGE_NAME}:${BUILD_VERSION}" \
    -t "${DOCKER_REGISTRY}/${DOCKER_USER}/${DOCKER_IMAGE_NAME}:latest" \
    -f Dockerfile .
