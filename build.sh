#!/usr/bin/env sh
# Build (and optionally push) alectrocute/tunbun to Docker Hub (docker.io).
#
#   ./build.sh                    # load into local Docker as alectrocute/tunbun:latest
#   VERSION=0.1.0 ./build.sh      # also tag alectrocute/tunbun:0.1.0
#   ./build.sh --push             # build single-arch for this machine, then push
#   ./build.sh --push --multiarch # buildx amd64+arm64 manifest, push (no local load)
#
# Push requires: docker login  (Docker Hub: alectrocute)

set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
cd "$ROOT"

DOCKER_USER="alectrocute"
IMAGE="${DOCKER_USER}/tunbun"
VERSION="${VERSION:-}"

PUSH=0
MULTIARCH=0
for arg in "$@"; do
  case "$arg" in
    --push) PUSH=1 ;;
    --multiarch) MULTIARCH=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./build.sh [--push] [--multiarch]

  (default)       docker build --load → alectrocute/tunbun:latest
  VERSION=x.y.z   also tag alectrocute/tunbun:x.y.z
  --push          build for this machine, then docker push
  --push --multiarch   buildx linux/amd64,arm64 and push manifest (needs --push)

Push: run docker login first (Docker Hub user alectrocute).
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 1
      ;;
  esac
done

if [ "$MULTIARCH" -eq 1 ] && [ "$PUSH" -eq 0 ]; then
  echo "tunbun: --multiarch requires --push (docker cannot --load a multi-arch image)" >&2
  exit 1
fi

tags=""
add_tags() {
  tags="${tags} -t ${IMAGE}:latest"
  if [ -n "$VERSION" ]; then
    tags="${tags} -t ${IMAGE}:${VERSION}"
  fi
}

add_tags

if [ "$PUSH" -eq 1 ] && [ "$MULTIARCH" -eq 1 ]; then
  docker buildx create --name tunbun-buildx --use 2>/dev/null \
    || docker buildx use tunbun-buildx
  # shellcheck disable=SC2086
  docker buildx build \
    --platform linux/amd64,linux/arm64 \
    $tags \
    --push \
    .
  echo "Pushed multi-arch: ${IMAGE}:latest${VERSION:+ and ${IMAGE}:${VERSION}}"
  exit 0
fi

if [ "$PUSH" -eq 1 ] && [ "$MULTIARCH" -eq 0 ]; then
  # shellcheck disable=SC2086
  docker build --load $tags .
  docker push "${IMAGE}:latest"
  if [ -n "$VERSION" ]; then
    docker push "${IMAGE}:${VERSION}"
  fi
  echo "Pushed: ${IMAGE}:latest${VERSION:+ and ${IMAGE}:${VERSION}}"
  exit 0
fi

# Local load only
# shellcheck disable=SC2086
docker build --load $tags .
echo "Loaded: ${IMAGE}:latest${VERSION:+ and ${IMAGE}:${VERSION}}"
