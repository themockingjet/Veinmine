#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Release}"
RELEASE_DIR="${RELEASE_DIR:-$PROJECT_ROOT/release}"
PACKAGE_NAME="${PACKAGE_NAME:-}"
PACKAGE_VERSION="${PACKAGE_VERSION:-${VERSION:-}}"

cd "$PROJECT_ROOT"
PROJECT="${PROJECT:-$(find src -type f -name '*.csproj' -print -quit)}"
if [[ "$RELEASE_DIR" != /* ]]; then
	RELEASE_DIR="$PROJECT_ROOT/$RELEASE_DIR"
fi
if [[ -z "$PACKAGE_VERSION" ]]; then
	PACKAGE_VERSION="$(sed -n \
		's/^[[:space:]]*"version_number"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
		Thunderstore/manifest.json | head -n 1)"
fi
[[ -n "$PACKAGE_VERSION" ]] || {
	printf 'Package version was not provided and could not be read from manifest.json.\n' >&2
	exit 1
}
if [[ -z "$PACKAGE_NAME" ]]; then
	PACKAGE_NAME="$(sed -n \
		's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
		Thunderstore/manifest.json | head -n 1)"
fi
[[ -n "$PACKAGE_NAME" ]] || {
	printf 'Package name was not provided and could not be read from manifest.json.\n' >&2
	exit 1
}
ARCHIVE_PATH="${ARCHIVE_PATH:-$RELEASE_DIR/${PACKAGE_NAME}-${PACKAGE_VERSION}.zip}"
if [[ "$ARCHIVE_PATH" != /* ]]; then
	ARCHIVE_PATH="$PROJECT_ROOT/$ARCHIVE_PATH"
fi
make validate-release

mkdir -p "$RELEASE_DIR"
stage_dir="$(mktemp -d "$RELEASE_DIR/.package.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT

cp Thunderstore/manifest.json \
	Thunderstore/README.md \
	Thunderstore/CHANGELOG.md \
	Thunderstore/icon.png \
	"$stage_dir/"

ASSEMBLY_NAME="${ASSEMBLY_NAME:-$(sed -n \
	's/^[[:space:]]*<AssemblyName>\([^<]*\)<\/AssemblyName>.*/\1/p' \
	"$PROJECT" | head -n 1)}"
if [[ -z "$ASSEMBLY_NAME" ]]; then
	ASSEMBLY_NAME="$(basename "$PROJECT" .csproj)"
fi
plugin_dll="$(find src -type f \
	-path "*/bin/$BUILD_CONFIGURATION/*/$ASSEMBLY_NAME.dll" \
	-print -quit)"
if [[ -z "$plugin_dll" ]]; then
	printf 'Built plugin DLL was not found under src/**/bin/%s/*: %s.dll\n' \
		"$BUILD_CONFIGURATION" "$ASSEMBLY_NAME" >&2
	printf 'Run scripts/build.sh before packaging.\n' >&2
	exit 1
fi

cp "$plugin_dll" "$stage_dir/$(basename "$plugin_dll")"

if [[ -n "${PACKAGE_DLLS:-}" ]]; then
	for assembly in $PACKAGE_DLLS; do
		[[ -f "$assembly" ]] || {
			printf 'Configured package DLL was not found: %s\n' "$assembly" >&2
			exit 1
		}
		cp "$assembly" "$stage_dir/$(basename "$assembly")"
	done
fi

rm -f "$ARCHIVE_PATH" "$ARCHIVE_PATH.sha256"
if command -v zip >/dev/null 2>&1; then
	(
		cd "$stage_dir"
		zip -q -r "$ARCHIVE_PATH" .
	)
else
	command -v python3 >/dev/null || {
		printf 'Packaging requires either zip or python3.\n' >&2
		exit 1
	}
	python3 - "$stage_dir" "$ARCHIVE_PATH" <<'PY'
import os
import sys
import zipfile

source_dir, archive_path = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED) as archive:
    for root, _, files in os.walk(source_dir):
        for filename in files:
            path = os.path.join(root, filename)
            archive.write(path, os.path.relpath(path, source_dir))
PY
fi
sha256sum "$ARCHIVE_PATH" > "$ARCHIVE_PATH.sha256"

printf 'Release package created: %s\n' "$ARCHIVE_PATH"