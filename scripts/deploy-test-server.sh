#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-Release}"
RELEASE_DIR="${RELEASE_DIR:-$PROJECT_ROOT/release}"
RELEASE_ARCHIVE="${RELEASE_ARCHIVE:-}"
PACKAGE_NAME="${PACKAGE_NAME:-}"
PACKAGE_VERSION="${PACKAGE_VERSION:-${VERSION:-}}"
TEST_SERVER="${TEST_SERVER:-}"
TEST_SERVER_SSH_OPTIONS="${TEST_SERVER_SSH_OPTIONS:-}"
TEST_SERVER_SUDO="${TEST_SERVER_SUDO-sudo}"
TEST_SERVER_PLUGIN_ROOT="${TEST_SERVER_PLUGIN_ROOT:-/opt/valheim/modpack/current/BepInEx/plugins}"
TEST_SERVER_PLUGIN_OWNER="${TEST_SERVER_PLUGIN_OWNER:-valheim:valheim}"
TEST_PLUGIN_DIR="${TEST_PLUGIN_DIR:-}"
TEST_ALLOW_NONLOCAL_PLUGIN_DIR="${TEST_ALLOW_NONLOCAL_PLUGIN_DIR:-0}"

usage() {
	cat <<'USAGE'
Usage: scripts/deploy-test-server.sh [--remove]

Deploy the built plugin package into a test server's active BepInEx release.

Required:
  TEST_SERVER=local               Use the local host.
  TEST_SERVER=user@host           Use an SSH target.

Useful overrides:
  TEST_SERVER_SSH_OPTIONS="-p 2222"
  TEST_SERVER_SUDO="sudo -n"
  TEST_PLUGIN_DIR="local-MyMod"
  TEST_SERVER_PLUGIN_ROOT=/opt/valheim/modpack/current/BepInEx/plugins
  RELEASE_ARCHIVE=/path/to/package.zip
USAGE
}

fail() {
	printf 'deploy-test-server: %s\n' "$1" >&2
	exit 1
}

ACTION=install
case "${1:-}" in
	'') ;;
	--remove) ACTION=remove ;;
	-h|--help) usage; exit 0 ;;
	*) usage >&2; exit 2 ;;
esac
if [[ $# -gt 1 ]]; then
	usage >&2
	exit 2
fi

[[ -n "$TEST_SERVER" ]] || {
	usage >&2
	exit 2
}
[[ "$TEST_SERVER_PLUGIN_ROOT" =~ ^/[A-Za-z0-9._/-]+$ ]] || \
	fail 'TEST_SERVER_PLUGIN_ROOT must be an absolute path using safe path characters'
[[ "$TEST_SERVER_PLUGIN_OWNER" =~ ^[A-Za-z_][A-Za-z0-9_-]*:[A-Za-z_][A-Za-z0-9_-]*$ ]] || \
	fail 'TEST_SERVER_PLUGIN_OWNER must have the form user:group'
[[ "$TEST_ALLOW_NONLOCAL_PLUGIN_DIR" == 0 || "$TEST_ALLOW_NONLOCAL_PLUGIN_DIR" == 1 ]] || \
	fail 'TEST_ALLOW_NONLOCAL_PLUGIN_DIR must be 0 or 1'

if [[ -z "$PACKAGE_NAME" ]]; then
	PACKAGE_NAME="$(sed -n \
		's/^[[:space:]]*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
		"$PROJECT_ROOT/Thunderstore/manifest.json" | head -n 1)"
fi
[[ -n "$PACKAGE_NAME" ]] || fail 'package name could not be read from Thunderstore/manifest.json'
if [[ -z "$PACKAGE_VERSION" ]]; then
	PACKAGE_VERSION="$(sed -n \
		's/^[[:space:]]*"version_number"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
		"$PROJECT_ROOT/Thunderstore/manifest.json" | head -n 1)"
fi
[[ -n "$PACKAGE_VERSION" ]] || fail 'package version could not be read from Thunderstore/manifest.json'

if [[ -z "$TEST_PLUGIN_DIR" ]]; then
	TEST_PLUGIN_DIR="local-$PACKAGE_NAME"
fi
[[ "$TEST_PLUGIN_DIR" =~ ^[A-Za-z0-9_.-]+$ ]] || \
	fail 'TEST_PLUGIN_DIR contains unsupported characters'
if [[ "$TEST_ALLOW_NONLOCAL_PLUGIN_DIR" != 1 && "$TEST_PLUGIN_DIR" != local-* ]]; then
	fail 'TEST_PLUGIN_DIR must start with local-; set TEST_ALLOW_NONLOCAL_PLUGIN_DIR=1 to override'
fi

if [[ "$RELEASE_DIR" != /* ]]; then
	RELEASE_DIR="$PROJECT_ROOT/$RELEASE_DIR"
fi
if [[ -n "$RELEASE_ARCHIVE" && "$RELEASE_ARCHIVE" != /* ]]; then
	RELEASE_ARCHIVE="$PROJECT_ROOT/$RELEASE_ARCHIVE"
fi
if [[ -z "$RELEASE_ARCHIVE" ]]; then
	RELEASE_ARCHIVE="$RELEASE_DIR/${PACKAGE_NAME}-${PACKAGE_VERSION}.zip"
fi

require_command() {
	command -v "$1" >/dev/null 2>&1 || fail "required command is missing: $1"
}

if [[ "$TEST_SERVER" != local ]]; then
	require_command ssh
	require_command scp
fi
if [[ "$ACTION" == install ]]; then
	require_command unzip
	[[ -f "$RELEASE_ARCHIVE" ]] || fail "release ZIP was not found: $RELEASE_ARCHIVE"
	unzip -tq "$RELEASE_ARCHIVE" >/dev/null || fail "release ZIP is invalid: $RELEASE_ARCHIVE"
fi

SSH_OPTIONS=()
if [[ -n "$TEST_SERVER_SSH_OPTIONS" ]]; then
	read -r -a SSH_OPTIONS <<< "$TEST_SERVER_SSH_OPTIONS"
fi
SUDO_COMMAND=()
if [[ -n "$TEST_SERVER_SUDO" ]]; then
	read -r -a SUDO_COMMAND <<< "$TEST_SERVER_SUDO"
fi

PACKAGE_STAGE=""
REMOTE_STAGE=""
cleanup() {
	if [[ -n "$PACKAGE_STAGE" ]]; then
		rm -rf -- "$PACKAGE_STAGE"
	fi
	if [[ -n "$REMOTE_STAGE" ]]; then
		ssh -T "${SSH_OPTIONS[@]}" "$TEST_SERVER" rm -rf -- "$REMOTE_STAGE" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

DLL_NAMES=()
if [[ "$ACTION" == install ]]; then
	PACKAGE_STAGE="$(mktemp -d)"
	mapfile -t DLL_MEMBERS < <(
		unzip -Z1 "$RELEASE_ARCHIVE" |
			awk 'index($0, "/") == 0 && tolower($0) ~ /[.]dll$/ { print }'
	)
	((${#DLL_MEMBERS[@]} > 0)) || fail 'release ZIP contains no root-level DLL'
	for member in "${DLL_MEMBERS[@]}"; do
		dll_name="${member##*/}"
		[[ "$dll_name" =~ ^[A-Za-z0-9_.-]+\.[dD][lL][lL]$ ]] || \
			fail "release ZIP contains an unsafe DLL name: $dll_name"
		[[ ! -e "$PACKAGE_STAGE/$dll_name" ]] || fail "release ZIP contains duplicate DLL name: $dll_name"
		unzip -p "$RELEASE_ARCHIVE" "$member" >"$PACKAGE_STAGE/$dll_name" || \
			fail "could not extract $member from release ZIP"
		chmod 0644 "$PACKAGE_STAGE/$dll_name"
		DLL_NAMES+=("$dll_name")
	done
fi

if [[ "$TEST_SERVER" == local ]]; then
	SOURCE_DIRECTORY="$PACKAGE_STAGE"
else
	REMOTE_STAGE="/tmp/valheim-test-deploy-${BASHPID}-${RANDOM}"
	ssh -T "${SSH_OPTIONS[@]}" "$TEST_SERVER" mkdir -- "$REMOTE_STAGE"
	if [[ "$ACTION" == install ]]; then
		STAGED_FILES=()
		for dll_name in "${DLL_NAMES[@]}"; do
			STAGED_FILES+=("$PACKAGE_STAGE/$dll_name")
		done
		scp "${SSH_OPTIONS[@]}" "${STAGED_FILES[@]}" "$TEST_SERVER:$REMOTE_STAGE/"
	fi
	SOURCE_DIRECTORY="$REMOTE_STAGE"
fi

install_payload() {
	cat <<'REMOTE_INSTALLER'
#!/usr/bin/env bash
set -Eeuo pipefail

action=$1
source_directory=$2
plugin_root=$3
plugin_directory=$4
owner=$5
allow_nonlocal_directory=$6
shift 6
dll_names=("$@")

fail() {
	printf 'deploy-test-server: %s\n' "$1" >&2
	exit 1
}

[[ "$action" == install || "$action" == remove ]] || fail 'invalid deployment action'
[[ "$plugin_root" =~ ^/[A-Za-z0-9._/-]+$ ]] || \
	fail 'plugin root must be an absolute path using safe path characters'
[[ "$plugin_directory" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'plugin directory contains unsupported characters'
if [[ "$allow_nonlocal_directory" != 1 && "$plugin_directory" != local-* ]]; then
	fail 'refusing to operate on a non-local plugin directory'
fi
[[ "$owner" =~ ^[A-Za-z_][A-Za-z0-9_-]*:[A-Za-z_][A-Za-z0-9_-]*$ ]] || \
	fail 'plugin owner must have the form user:group'
[[ -d "$plugin_root" ]] || fail "plugin root does not exist: $plugin_root"

target_directory="$plugin_root/$plugin_directory"
if [[ -L "$target_directory" ]]; then
	fail "refusing to operate on symlink: $target_directory"
fi
if [[ -e "$target_directory" && ! -d "$target_directory" ]]; then
	fail "plugin target is not a directory: $target_directory"
fi
if [[ "$action" == remove && ! -e "$target_directory" ]]; then
	printf 'Test plugin is not installed: %s\n' "$target_directory"
	exit 0
fi
if [[ "$action" == install ]]; then
	((${#dll_names[@]} > 0)) || fail 'no DLLs were provided for installation'
	[[ -d "$source_directory" ]] || fail "staged DLL directory does not exist: $source_directory"
	for dll_name in "${dll_names[@]}"; do
		[[ "$dll_name" =~ ^[A-Za-z0-9_.-]+\.[dD][lL][lL]$ ]] || \
			fail "DLL name contains unsupported characters: $dll_name"
		[[ -f "$source_directory/$dll_name" ]] || fail "staged DLL is missing: $dll_name"
	done
fi

owner_user="${owner%%:*}"
owner_group="${owner#*:}"
staged_directory="$plugin_root/.${plugin_directory}.install.$$"
backup_directory="$plugin_root/.${plugin_directory}.backup.$$"
backup_moved=0
new_target_moved=0

restore_state() {
	exit_code=$?
	if ((exit_code != 0)); then
		if ((new_target_moved)); then
			/usr/bin/rm -rf -- "$target_directory"
		fi
		if ((backup_moved)); then
			/usr/bin/mv -- "$backup_directory" "$target_directory" || exit_code=1
		fi
	fi
	/usr/bin/rm -rf -- "$staged_directory"
	exit "$exit_code"
}
trap restore_state EXIT

if [[ "$action" == install ]]; then
	/usr/bin/install -d -o "$owner_user" -g "$owner_group" -m 0750 "$staged_directory"
	for dll_name in "${dll_names[@]}"; do
		/usr/bin/install -o "$owner_user" -g "$owner_group" -m 0644 \
			"$source_directory/$dll_name" "$staged_directory/$dll_name"
	done
fi
if [[ -e "$target_directory" ]]; then
	/usr/bin/mv -- "$target_directory" "$backup_directory"
	backup_moved=1
fi
if [[ "$action" == install ]]; then
	/usr/bin/mv -- "$staged_directory" "$target_directory"
	new_target_moved=1
fi

if [[ "$action" == install ]]; then
	printf 'Installed test plugin: %s\n' "$target_directory"
else
	printf 'Removed test plugin: %s\n' "$target_directory"
fi

/usr/bin/rm -rf -- "$backup_directory" "$staged_directory"
trap - EXIT
REMOTE_INSTALLER
}

INSTALL_ARGUMENTS=(
	"$ACTION"
	"$SOURCE_DIRECTORY"
	"$TEST_SERVER_PLUGIN_ROOT"
	"$TEST_PLUGIN_DIR"
	"$TEST_SERVER_PLUGIN_OWNER"
	"$TEST_ALLOW_NONLOCAL_PLUGIN_DIR"
)
INSTALL_ARGUMENTS+=("${DLL_NAMES[@]}")

if [[ "$TEST_SERVER" == local ]]; then
	if ((${#SUDO_COMMAND[@]} > 0)); then
		install_payload | "${SUDO_COMMAND[@]}" bash -s -- "${INSTALL_ARGUMENTS[@]}"
	else
		install_payload | bash -s -- "${INSTALL_ARGUMENTS[@]}"
	fi
else
	if ((${#SUDO_COMMAND[@]} > 0)); then
		install_payload | ssh -T "${SSH_OPTIONS[@]}" "$TEST_SERVER" \
			"${SUDO_COMMAND[@]}" bash -s -- "${INSTALL_ARGUMENTS[@]}"
	else
		install_payload | ssh -T "${SSH_OPTIONS[@]}" "$TEST_SERVER" \
			bash -s -- "${INSTALL_ARGUMENTS[@]}"
	fi
fi

if [[ "$ACTION" == install ]]; then
	printf 'Test-server deployment completed for %s\n' "$PACKAGE_NAME"
else
	printf 'Test-server removal completed for %s\n' "$TEST_PLUGIN_DIR"
fi