# epic-prefill-docker

Creates Docker image (and contains `docker-compose.yml`) based on https://github.com/tpill90/epic-lancache-prefill every day at 06:00 UTC (the pipeline schedule), for `linux/amd64` and `linux/arm64`

## Rebuilding the current version

The scheduled pipeline builds only when upstream has a newer release. To rebuild and re-push the
current version (both `<version>` and `latest` tags) — e.g. to ship a Dockerfile fix before the next
upstream release — run a pipeline on `master` with the variable `FORCE_BUILD=true` (Build → Pipelines
→ Run pipeline), or locally: `FORCE_BUILD=true ./build-and-push.sh`.
