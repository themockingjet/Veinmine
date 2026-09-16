SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:

.DEFAULT_GOAL := help

VALHEIM_ENV_FILE ?= $(HOME)/.config/valheim-dev/env.sh
ifneq ($(wildcard $(VALHEIM_ENV_FILE)),)
VALHEIM_PATH ?= $(shell . "$(VALHEIM_ENV_FILE)" && printf '%s' "$$VALHEIM_PATH")
VALHEIM_DEV_ROOT ?= $(shell . "$(VALHEIM_ENV_FILE)" && printf '%s' "$$VALHEIM_DEV_ROOT")
VALHEIM_MANAGED_PATH ?= $(shell . "$(VALHEIM_ENV_FILE)" && printf '%s' "$$VALHEIM_MANAGED_PATH")
BEPINEX_PATH ?= $(shell . "$(VALHEIM_ENV_FILE)" && printf '%s' "$$BEPINEX_PATH")
VALHEIM_RELEASE_PATH ?= $(shell . "$(VALHEIM_ENV_FILE)" && printf '%s' "$$VALHEIM_RELEASE_PATH")
endif
VALHEIM_PATH ?= $(HOME)/valheim-server
VALHEIM_DEV_ROOT ?= $(HOME)/valheim-dev
VALHEIM_MANAGED_PATH ?= $(VALHEIM_DEV_ROOT)/managed
BEPINEX_PATH ?= $(VALHEIM_DEV_ROOT)/BepInEx
VALHEIM_RELEASE_PATH ?= $(VALHEIM_DEV_ROOT)/release
export VALHEIM_PATH VALHEIM_DEV_ROOT VALHEIM_MANAGED_PATH BEPINEX_PATH VALHEIM_RELEASE_PATH
SERVERSYNC_PATH ?= $(BEPINEX_PATH)/core/ServerSync.dll

SOLUTION ?= $(firstword $(wildcard *.sln))
PROJECT ?= $(firstword $(wildcard src/*/*.csproj))
RELEASE_DIR ?= release

TEST_SERVER ?=
TEST_SERVER_SSH_OPTIONS ?=
TEST_SERVER_SUDO ?= sudo
TEST_SERVER_PLUGIN_ROOT ?= /opt/valheim/modpack/current/BepInEx/plugins
TEST_SERVER_PLUGIN_OWNER ?= valheim:valheim
TEST_PLUGIN_DIR ?=
TEST_ALLOW_NONLOCAL_PLUGIN_DIR ?= 0
RELEASE_ARCHIVE ?=
PACKAGE_NAME ?=
PACKAGE_VERSION ?=

.PHONY: help validate-env validate-build validate-release preflight \
	before-build before-release setup-references build package verify-release \
	deploy-test-server remove-test-server

help:
	@printf '%s\n' \
		'Valheim mod validation targets:' \
		'  make validate-env      Check WSL paths, required DLLs, and .NET' \
		'  make validate-build    Check solution, project, and build inputs' \
		'  make validate-release  Check Thunderstore and release inputs' \
		'  make preflight         Run all checks before building or releasing' \
		'  make build             Validate and build the mod' \
		'  make package           Validate and create the release ZIP' \
		'  make verify-release    Validate the release ZIP contents' \
		'  make deploy-test-server TEST_SERVER=local' \
		'                             Build, package, and install into a test server' \
		'  make remove-test-server TEST_SERVER=local' \
		'                             Remove the local test install' \
		'  make setup-references  Set up the shared Valheim references' \
		'' \
		'The environment is normally loaded with:' \
		'  source "$$HOME/.config/valheim-dev/env.sh"' \
		'' \
		'ServerSync reference:' \
		'  SERVERSYNC_PATH=$$BEPINEX_PATH/core/ServerSync.dll' \
		'' \
		'Override project discovery when needed:' \
		'  make preflight SOLUTION=MyMod.sln PROJECT=src/MyMod/MyMod.csproj'

validate-env:
	required_env=( \
		VALHEIM_PATH \
		VALHEIM_DEV_ROOT \
		VALHEIM_MANAGED_PATH \
		BEPINEX_PATH \
		VALHEIM_RELEASE_PATH \
	)
	missing=0
	for name in "$${required_env[@]}"; do
		if [[ -z "$${!name:-}" ]]; then
			printf 'Missing environment variable: %s\n' "$$name" >&2
			missing=1
		fi
	done
	(( missing == 0 )) || {
		printf 'Source ~/.config/valheim-dev/env.sh before running this check.\n' >&2
		exit 1
	}

	for directory in \
		"$$VALHEIM_PATH" \
		"$$VALHEIM_MANAGED_PATH" \
		"$$BEPINEX_PATH" \
		"$$BEPINEX_PATH/core" \
		"$$VALHEIM_RELEASE_PATH"; do
		if [[ ! -d "$$directory" ]]; then
			printf 'Missing required directory: %s\n' "$$directory" >&2
			exit 1
		fi
	done

	for file in \
		"$$VALHEIM_PATH/valheim_server_Data/Managed/assembly_valheim.dll" \
		"$$VALHEIM_MANAGED_PATH/assembly_valheim.dll" \
		"$$VALHEIM_MANAGED_PATH/assembly_utils.dll" \
		"$$VALHEIM_MANAGED_PATH/assembly_guiutils.dll" \
		"$$VALHEIM_MANAGED_PATH/UnityEngine.dll" \
		"$$VALHEIM_MANAGED_PATH/UnityEngine.CoreModule.dll" \
		"$$VALHEIM_MANAGED_PATH/UnityEngine.InputLegacyModule.dll" \
		"$$VALHEIM_MANAGED_PATH/UnityEngine.PhysicsModule.dll" \
		"$$BEPINEX_PATH/core/BepInEx.dll" \
		"$$BEPINEX_PATH/core/0Harmony.dll"; do
		if [[ ! -f "$$file" ]]; then
			printf 'Missing required build reference: %s\n' "$$file" >&2
			exit 1
		fi
	done

	command -v dotnet >/dev/null || {
		printf 'Required command is not installed: dotnet\n' >&2
		exit 1
	}
	dotnet --version
	printf 'Environment is ready for a Valheim build.\n'

validate-build: validate-env
	if [[ -z "$(SOLUTION)" || ! -f "$(SOLUTION)" ]]; then
		printf 'Solution file was not found. Set SOLUTION=<path-to-sln>.\n' >&2
		exit 1
	fi
	if [[ -z "$(PROJECT)" || ! -f "$(PROJECT)" ]]; then
		printf 'Project file was not found. Set PROJECT=<path-to-csproj>.\n' >&2
		exit 1
	fi
	test -f Directory.Build.props || {
		printf 'Missing build configuration: Directory.Build.props\n' >&2
		exit 1
	}
	test -f Directory.Build.targets || {
		printf 'Missing build configuration: Directory.Build.targets\n' >&2
		exit 1
	}
	test -f src/*/ILRepack.targets || {
		printf 'Missing ILRepack configuration: src/*/ILRepack.targets\n' >&2
		exit 1
	}
	test -f global.json || {
		printf 'Missing SDK configuration: global.json\n' >&2
		exit 1
	}
	test -x scripts/build.sh || {
		printf 'Build script is missing or not executable: scripts/build.sh\n' >&2
		exit 1
	}
	test -f "$(SERVERSYNC_PATH)" || {
		printf 'Missing ServerSync reference: %s\n' "$(SERVERSYNC_PATH)" >&2
		printf 'Install ServerSync.dll in the BepInEx core reference directory.\n' >&2
		exit 1
	}
	printf 'Build inputs are ready: %s\n' "$(SOLUTION)"
	printf 'Plugin project is ready: %s\n' "$(PROJECT)"

validate-release: validate-build
	for file in \
		Thunderstore/manifest.json \
		Thunderstore/README.md \
		Thunderstore/CHANGELOG.md \
		Thunderstore/icon.png \
		scripts/package.sh \
		scripts/verify-release.sh; do
		if [[ ! -s "$$file" ]]; then
			printf 'Missing release input: %s\n' "$$file" >&2
			exit 1
		fi
	done
	test -x scripts/package.sh || {
		printf 'Release script is not executable: scripts/package.sh\n' >&2
		exit 1
	}
	test -x scripts/verify-release.sh || {
		printf 'Release script is not executable: scripts/verify-release.sh\n' >&2
		exit 1
	}
	if ! command -v zip >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
		printf 'Required packaging command is not installed: zip or python3\n' >&2
		exit 1
	fi
	command -v unzip >/dev/null || {
		printf 'Required command is not installed: unzip\n' >&2
		exit 1
	}
	command -v sha256sum >/dev/null || {
		printf 'Required command is not installed: sha256sum\n' >&2
		exit 1
	}
	printf 'Release inputs are ready.\n'

preflight: validate-release
	printf 'Preflight validation passed. Build and release inputs are ready.\n'

before-build: validate-build
before-release: validate-release

setup-references:
	./scripts/setup-valheim-references.sh

build: before-build
	SERVERSYNC_PATH="$(SERVERSYNC_PATH)" ./scripts/build.sh

package: before-release
	./scripts/package.sh

verify-release: before-release
	./scripts/verify-release.sh

deploy-test-server: build
	RELEASE_DIR="$(RELEASE_DIR)" \
	PACKAGE_NAME="$(PACKAGE_NAME)" \
	PACKAGE_VERSION="$(PACKAGE_VERSION)" \
	./scripts/package.sh
	RELEASE_DIR="$(RELEASE_DIR)" \
	RELEASE_ARCHIVE="$(RELEASE_ARCHIVE)" \
	./scripts/verify-release.sh
	TEST_SERVER="$(TEST_SERVER)" \
	TEST_SERVER_SSH_OPTIONS="$(TEST_SERVER_SSH_OPTIONS)" \
	TEST_SERVER_SUDO="$(TEST_SERVER_SUDO)" \
	TEST_SERVER_PLUGIN_ROOT="$(TEST_SERVER_PLUGIN_ROOT)" \
	TEST_SERVER_PLUGIN_OWNER="$(TEST_SERVER_PLUGIN_OWNER)" \
	TEST_PLUGIN_DIR="$(TEST_PLUGIN_DIR)" \
	TEST_ALLOW_NONLOCAL_PLUGIN_DIR="$(TEST_ALLOW_NONLOCAL_PLUGIN_DIR)" \
	RELEASE_DIR="$(RELEASE_DIR)" \
	RELEASE_ARCHIVE="$(RELEASE_ARCHIVE)" \
	PACKAGE_NAME="$(PACKAGE_NAME)" \
	PACKAGE_VERSION="$(PACKAGE_VERSION)" \
	./scripts/deploy-test-server.sh

remove-test-server:
	TEST_SERVER="$(TEST_SERVER)" \
	TEST_SERVER_SSH_OPTIONS="$(TEST_SERVER_SSH_OPTIONS)" \
	TEST_SERVER_SUDO="$(TEST_SERVER_SUDO)" \
	TEST_SERVER_PLUGIN_ROOT="$(TEST_SERVER_PLUGIN_ROOT)" \
	TEST_SERVER_PLUGIN_OWNER="$(TEST_SERVER_PLUGIN_OWNER)" \
	TEST_PLUGIN_DIR="$(TEST_PLUGIN_DIR)" \
	TEST_ALLOW_NONLOCAL_PLUGIN_DIR="$(TEST_ALLOW_NONLOCAL_PLUGIN_DIR)" \
	PACKAGE_NAME="$(PACKAGE_NAME)" \
	./scripts/deploy-test-server.sh --remove