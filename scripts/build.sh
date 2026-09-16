#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SOLUTION="${SOLUTION:-}"
PROJECT="${PROJECT:-}"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Release}"
RELEASE_OUTPUT_PATH="${RELEASE_OUTPUT_PATH:-$PROJECT_ROOT/release}"

cd "$PROJECT_ROOT"
make validate-build
SERVERSYNC_PATH="${SERVERSYNC_PATH:-$BEPINEX_PATH/core/ServerSync.dll}"

if [[ -z "$SOLUTION" ]]; then
	SOLUTION="$(find . -maxdepth 1 -type f -name '*.sln' -print -quit)"
fi
if [[ -z "$PROJECT" ]]; then
	PROJECT="$(find src -type f -name '*.csproj' -print -quit)"
fi

[[ -n "$SOLUTION" && -f "$SOLUTION" ]] || {
	printf 'Solution file was not found.\n' >&2
	exit 1
}
[[ -n "$PROJECT" && -f "$PROJECT" ]] || {
	printf 'Project file was not found.\n' >&2
	exit 1
}

dotnet build "$SOLUTION" \
	-c "$BUILD_CONFIGURATION" \
	-p:ValheimManagedPath="$VALHEIM_MANAGED_PATH" \
	-p:BepInExPath="$BEPINEX_PATH" \
	-p:ServerSyncPath="$SERVERSYNC_PATH" \
	-p:ReleaseOutputPath="$RELEASE_OUTPUT_PATH"