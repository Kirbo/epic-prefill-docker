# docker buildx build --build-arg PREFILL_VERSION=latest --platform linux/amd64,linux/arm64 -t kirbownz/epic-prefill-docker:latest
# docker push kirbownz/epic-prefill-docker:latest
# docker run -v ${PWD}/Cache:/app/Cache -v ${PWD}/Config:/app/Config --rm kirbownz/epic-prefill-docker:latest version


# The download stage runs natively on the build host and fetches the upstream binary for the image's
# TARGET architecture (upstream publishes a linux-x64 and a linux-arm64 zip).
FROM --platform=$BUILDPLATFORM alpine:3 AS download
ARG PREFILL_VERSION=latest
ARG TARGETARCH
RUN \
    apk --no-cache add curl && \
    ARCH=$([ "${TARGETARCH}" = "arm64" ] && echo arm64 || echo x64) && \
    cd /tmp && \
    LATEST_RELEASE_LINK=$(curl -s https://api.github.com/repos/tpill90/epic-lancache-prefill/releases/latest | grep 'browser_' | cut -d\" -f4 | grep "linux-${ARCH}") && \
    LATEST_VERSION=$(echo ${LATEST_RELEASE_LINK} | sed 's/.*-\(.*\)-.*-.*/\1/') && \
    DOWNLOAD_VERSION=$([ "${PREFILL_VERSION}" == "latest" ] && echo ${LATEST_VERSION} || echo ${PREFILL_VERSION}) && \
    DOWNLOAD_URL=$([ "${PREFILL_VERSION}" == "latest" ] && echo ${LATEST_RELEASE_LINK} || echo https://github.com/tpill90/epic-lancache-prefill/releases/download/v${DOWNLOAD_VERSION}/EpicPrefill-${DOWNLOAD_VERSION}-linux-${ARCH}.zip) && \
    wget -O EpicPrefill.zip ${DOWNLOAD_URL} && \
    unzip EpicPrefill && \
    mv EpicPrefill-${DOWNLOAD_VERSION}-linux-${ARCH}/EpicPrefill EpicPrefill && \
    chmod +x EpicPrefill


FROM ubuntu:22.04
LABEL maintainer="@kirbownz"
LABEL description="Epic Prefill Docker Image"

ARG DEBIAN_FRONTEND=noninteractive
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
RUN \
    apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /app

COPY --from=download /tmp/EpicPrefill /app/EpicPrefill

WORKDIR /app
ENTRYPOINT [ "/app/EpicPrefill" ]
