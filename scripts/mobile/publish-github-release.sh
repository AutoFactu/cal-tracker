#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST_DIR="$ROOT_DIR/dist/mobile/android"
ENVIRONMENT="${1:-}"
TAG="${2:-}"

usage() {
  cat <<'USAGE'
Usage:
  scripts/mobile/publish-github-release.sh dev [tag]
  scripts/mobile/publish-github-release.sh prod [tag]

Creates or updates a GitHub Release with the locally-built APK and checksum.
Tags intentionally do not start with "v" because this repository deploys the
backend to production from v* tags.

Environment variables:
  ALLOW_DIRTY=1  Allows publishing from a dirty working tree
USAGE
}

case "$ENVIRONMENT" in
  dev|prod) ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install it and run: gh auth login" >&2
  exit 1
fi

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" && "${ALLOW_DIRTY:-}" != "1" ]]; then
  cat >&2 <<'MESSAGE'
Refusing to publish from a dirty working tree.

Commit and push the exact source you want to publish, or set ALLOW_DIRTY=1 if
you intentionally want a local-only build attached to a release.
MESSAGE
  exit 1
fi

target_sha="$(git -C "$ROOT_DIR" rev-parse HEAD)"
short_sha="$(git -C "$ROOT_DIR" rev-parse --short HEAD)"

if ! git -C "$ROOT_DIR" branch -r --contains "$target_sha" | grep -q 'origin/'; then
  echo "Current commit is not present on origin. Push it before publishing a release." >&2
  exit 1
fi

"$ROOT_DIR/scripts/mobile/build-android.sh" "$ENVIRONMENT"

version="$(sed -n 's/^version:[[:space:]]*//p' "$ROOT_DIR/apps/mobile/pubspec.yaml" | head -n 1 | tr '+' '-')"
if [[ -z "$TAG" ]]; then
  TAG="mobile-$ENVIRONMENT-$version-$short_sha"
fi

if [[ "$TAG" == v* ]]; then
  echo "Refusing mobile release tag '$TAG': v* tags deploy the backend to production in this repo." >&2
  exit 1
fi

shopt -s nullglob
assets=("$DIST_DIR"/bettercalories-"$ENVIRONMENT"-"$version"-"$short_sha".apk "$DIST_DIR"/bettercalories-"$ENVIRONMENT"-"$version"-"$short_sha".apk.sha256)
shopt -u nullglob

if [[ "${#assets[@]}" -eq 0 ]]; then
  echo "No APK assets found for $ENVIRONMENT in $DIST_DIR." >&2
  exit 1
fi

title="BetterCalories Android $ENVIRONMENT $version"
notes="Android $ENVIRONMENT APK built locally from $short_sha."
release_args=()
if [[ "$ENVIRONMENT" == "dev" ]]; then
  release_args+=(--prerelease)
fi

if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "${assets[@]}" --clobber
else
  gh release create "$TAG" "${assets[@]}" \
    --target "$target_sha" \
    --title "$title" \
    --notes "$notes" \
    "${release_args[@]}"
fi

echo "Published GitHub Release: $TAG"
