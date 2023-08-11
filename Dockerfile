# docker build . --build-arg PREFILL_VERSION=latest -t kirbownz/epic-prefill-docker:latest
# docker push kirbownz/epic-prefill-docker:latest
# docker run -v ${PWD}/Cache:/app/Cache -v ${PWD}/Config:/app/Config --rm kirbownz/epic-prefill-docker:latest version


FROM --platform=linux/amd64 alpine:3 AS download
ARG PREFILL_VERSION=latest
RUN \
    apk --no-cache add curl && \
    cd /tmp && \
    LATEST_RELEASE_LINK=$(curl -s https://api.github.com/repos/tpill90/epic-lancache-prefill/releases/latest | grep 'browser_' | cut -d\" -f4 | grep 'linux-x64') && \
    LATEST_VERSION=$(echo ${LATEST_RELEASE_LINK} | sed 's/.*-\(.*\)-.*-.*/\1/') && \
    DOWNLOAD_VERSION=$([ "${PREFILL_VERSION}" == "latest" ] && echo ${LATEST_VERSION} || echo ${PREFILL_VERSION}) && \
    DOWNLOAD_URL=$([ "${PREFILL_VERSION}" == "latest" ] && echo ${LATEST_RELEASE_LINK} || echo https://github.com/tpill90/epic-lancache-prefill/releases/download/v${DOWNLOAD_VERSION}/EpicPrefill-${DOWNLOAD_VERSION}-linux-x64.zip) && \
    wget -O EpicPrefill.zip ${DOWNLOAD_URL} && \
    unzip EpicPrefill && \
    mv EpicPrefill-${DOWNLOAD_VERSION}-linux-x64/EpicPrefill EpicPrefill && \
    chmod +x EpicPrefill


FROM --platform=linux/amd64 ubuntu:22.04
LABEL maintainer="kirbo@kirbo-designs.com"

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
