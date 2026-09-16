#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SETUP_DIR="${VALHEIM_SETUP_DIR:-$PROJECT_ROOT/../valheim-mod-setup}"

if [[ ! -f "$SETUP_DIR/Makefile" ]]; then
	printf 'Valheim setup Makefile was not found: %s/Makefile\n' "$SETUP_DIR" >&2
	printf 'Set VALHEIM_SETUP_DIR to the valheim-mod-setup directory.\n' >&2
	exit 1
fi

make -C "$SETUP_DIR" setup

printf '\nReference setup completed.\n'
printf 'Source the generated environment before building:\n'
printf '  source "%s/.config/valheim-dev/env.sh"\n' "$HOME"
