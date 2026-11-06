---
name: maintain
description: Maintenance pass for epic-prefill-docker — check the upstream EpicPrefill release and its per-arch assets, bump and digest-pin the base and CI images, verify the multi-arch build, check the scheduled pipeline and the runner routing, reconcile the README, report, commit. Use when the user runs /maintain or asks for a maintenance/housekeeping pass on this repo.
---

# epic-prefill-docker maintenance pass

**What this repo is:** it builds `kirbownz/epic-prefill-docker` (Docker Hub, `linux/amd64` + `linux/arm64`) from
the upstream releases of [tpill90/epic-lancache-prefill](https://github.com/tpill90/epic-lancache-prefill). A GitLab
schedule ("daily build", `0 6 * * *` Etc/UTC, on `master`) runs `build-and-push.sh`, which builds and
pushes only when upstream has a release newer than the newest image tag. **Sibling repos:** `steam-prefill-docker`, `battlenet-prefill-docker`
share this CI file, `build-and-push.sh` and the Dockerfile structure — make every change in all three.

Work from ground truth (the registries, upstream, the live pipeline), finish with a report and
logically scoped Conventional Commits. **Never push without the owner's OK.**

## Phase 1 — Upstream
1. `curl -s https://api.github.com/repos/tpill90/epic-lancache-prefill/releases/latest | jq '{tag_name, published_at, assets: [.assets[].name]}'`
   (set `Authorization: Bearer <token>` if rate-limited).
2. The assets must include `EpicPrefill-<version>-linux-x64.zip` AND `…-linux-arm64.zip`: the Dockerfile's
   download stage picks one by `TARGETARCH` (`arm64` → `arm64`, else `x64`). If upstream renamed them,
   fix the Dockerfile's `grep "linux-${ARCH}"` / `DOWNLOAD_URL` / `mv` lines and `build-and-push.sh`
   (it reads the version from the `linux-x64` asset name).
3. Compare with the newest Docker Hub tag:
   `curl -s "https://registry.hub.docker.com/v2/repositories/kirbownz/epic-prefill-docker/tags?page_size=5" | jq -r '.results[].name'`.
   Behind for more than a day = the schedule is not publishing → Phase 4.

## Phase 2 — Image pins (release-age rule: a version at least 7 days old)
1. Dockerfile bases: `alpine:3` (download stage, runs on the build host) and `ubuntu:22.04` (the
   runtime). Consider the current Ubuntu LTS; prefer pinning both by digest
   (`docker buildx imagetools inspect <image:tag> --format '{{json .Manifest.Digest}}'`).
2. The CI job image in `.gitlab-ci.yml`: `docker:<version>-cli@sha256:<digest>` (it must ship the
   buildx plugin). Newest `docker:<x.y.z>-cli` at least 7 days old; update the tag comment + digest.
3. Rebuild nothing by hand: the next schedule (or a manual "Run pipeline" on `master`) builds only
   when upstream moved — to prove a pin change, run the pipeline and watch `docker buildx inspect --bootstrap`.
   To ship an image change (base, Dockerfile) before the next upstream release, run the pipeline on
   `master` with `FORCE_BUILD=true`: it rebuilds and re-pushes the current version (`<version>` + `latest`).

## Phase 3 — Verify the build (no push)
- `glab ci lint .gitlab-ci.yml` (from the repo) — GitLab's own validation.
- A multi-arch build without push, e.g. on the Mac Mini (`ssh kirbo@Kirbo-Mini.local`):
  `docker buildx build --platform linux/amd64,linux/arm64 --build-arg PREFILL_VERSION=latest -f Dockerfile .`
  and a smoke run of each arch: `docker run --rm --platform linux/arm64 <image> version` (it must print
  the upstream version — an arm64 image with an x64 binary fails here).

## Phase 4 — CI health
- Last scheduled pipelines: `glab api "projects/kirbo%2Fepic-prefill-docker/pipelines?per_page=5" | jq -r '.[] | "\(.created_at) \(.source) \(.status)"'`;
  the schedule is active: `glab api "projects/kirbo%2Fepic-prefill-docker/pipeline_schedules"`.
- Runner routing (docs on the Mac Mini: `~/Documents/Claude/GitLab/BuildKit.md`): jobs use
  `tags: [$MAC_DOCKER]` — `macos-protected` on protected refs, `macos` otherwise — never the tag itself;
  the push job runs on protected refs only; it builds through the **protected BuildKit server**
  (`--driver remote`, File variables `BUILDKIT_PROTECTED_CA/CERT/KEY`) — never the Docker socket
  (`DOCKER_HOST`), never `--driver docker-container`, never Docker-in-Docker.
- Secrets: `CI_REGISTRY`, `CI_REGISTRY_USER`, `CI_REGISTRY_TOKEN` are protected variables (names only:
  `glab api "projects/kirbo%2Fepic-prefill-docker/variables" | jq -r '.[] | "\(.key) protected=\(.protected)"'`).
- The BuildKit client certificate expires 2029-02-08 (1Password "Kirbo Mini BuildKit protected mTLS").

## Phase 5 — Docs
`README.md`: the schedule time (06:00 UTC), the platforms, the `docker-compose.yml` / `docker run`
examples still match the Dockerfile's `ENTRYPOINT` and volumes (`/app/Cache`, `/app/Config`).

## Phase 6 — Report, then commit
Report per phase: upstream version vs image, pins bumped (old → new), what was verified and how,
CI health, doc fixes, anything held back (and why). Commit in logically scoped Conventional Commits
(`fix(docker):`, `chore(deps):`, `docs:`), each ending with the Co-Authored-By trailer. Do not push.
