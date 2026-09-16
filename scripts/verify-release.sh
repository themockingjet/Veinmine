#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RELEASE_DIR="${RELEASE_DIR:-$PROJECT_ROOT/release}"
RELEASE_ARCHIVE="${RELEASE_ARCHIVE:-}"

cd "$PROJECT_ROOT"
if [[ "$RELEASE_DIR" != /* ]]; then
	RELEASE_DIR="$PROJECT_ROOT/$RELEASE_DIR"
fi
if [[ -n "$RELEASE_ARCHIVE" && "$RELEASE_ARCHIVE" != /* ]]; then
	RELEASE_ARCHIVE="$PROJECT_ROOT/$RELEASE_ARCHIVE"
fi
make validate-release

if [[ -z "$RELEASE_ARCHIVE" ]]; then
	RELEASE_ARCHIVE="$(find "$RELEASE_DIR" -maxdepth 1 -type f -name '*.zip' \
		-print -quit)"
fi

[[ -n "$RELEASE_ARCHIVE" && -f "$RELEASE_ARCHIVE" ]] || {
	printf 'Release ZIP was not found in %s.\n' "$RELEASE_DIR" >&2
	printf 'Run scripts/package.sh before verifying the release.\n' >&2
	exit 1
}

unzip -tq "$RELEASE_ARCHIVE"
mapfile -t archive_files < <(unzip -Z1 "$RELEASE_ARCHIVE")

required_files=(
	manifest.json
	README.md
	CHANGELOG.md
	icon.png
	Veinmine.dll
)
for required_file in "${required_files[@]}"; do
	if ! printf '%s\n' "${archive_files[@]}" | grep -Fxq "$required_file"; then
		printf 'Release ZIP is missing required file: %s\n' "$required_file" >&2
		exit 1
	fi
done

if (( ${#archive_files[@]} != ${#required_files[@]} )); then
	printf 'Release ZIP contains unexpected files; expected exactly:\n' >&2
	printf '  %s\n' "${required_files[@]}" >&2
	printf 'Found:\n' >&2
	printf '  %s\n' "${archive_files[@]}" >&2
	exit 1
fi

for archive_file in "${archive_files[@]}"; do
	if ! printf '%s\n' "${required_files[@]}" | grep -Fxq "$archive_file"; then
		printf 'Release ZIP contains an unexpected file: %s\n' "$archive_file" >&2
		exit 1
	fi
done

for forbidden_pattern in \
	'^assembly_.*\.dll$' \
	'^UnityEngine.*\.dll$' \
	'^BepInEx\.dll$' \
	'^0Harmony\.dll$' \
	'^ServerSync\.dll$'; do
	if printf '%s\n' "${archive_files[@]}" | grep -Eq "$forbidden_pattern"; then
		printf 'Release ZIP contains forbidden game or loader reference files.\n' >&2
		exit 1
	fi
done

if [[ -f "$RELEASE_ARCHIVE.sha256" ]]; then
	(
		cd "$(dirname "$RELEASE_ARCHIVE")"
		sha256sum -c "$(basename "$RELEASE_ARCHIVE").sha256"
	)
fi

printf 'Release package is valid: %s\n' "$RELEASE_ARCHIVE"
