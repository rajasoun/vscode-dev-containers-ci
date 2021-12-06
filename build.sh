#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/src/load.sh"

VERSION=$(git describe --tags --abbrev=0 | awk -F. '{OFS="."; $NF+=1; print $0}')

DOCKER_BUILDKIT=1
DEBUG_OFF=""
DEBUG_TOGGLE="${2:-$DEBUG_OFF}"

export DOCKER_BUILDKIT

init_env_variables
_debug_option "$DEBUG_TOGGLE"
check jq
_file_exist "$DEV_CONTAINER_JSON_PATH"

opt="$1"
choice=$(tr '[:upper:]' '[:lower:]' <<<"$opt")
echo "Starting --> $choice "
case ${choice} in
"e2e")
    build_container >/dev/null 2>&1
    e2e_tests
    tear_down
    ;;
"publish")
    cd .devcontainer/prebuild && make push && cd - || return
    # git tag -a "$VERSION" -m "Dev Container new Build $VERSION"
    # git push origin "$VERSION" --no-verify
    echo "FROM rajasoun/devcontainer:$VERSION" >.devcontainer/prebuild/Dockerfile.prebuilt
    ;;
"build")
    build_container
    cd .devcontainer/prebuild || return
    sudo make build
    cd - || return
    debug "Removing Intermediate Container"
    docker rmi "rajasoun/application-profiler:$VERSION"
    echo "$VERSION" >.devcontainer/version.txt
    ;;
"teardown")
    tear_down
    ;;
*)
    echo "${RED}Usage: automator/ci.sh <build | e2e | publish | teardown > [-d]${NC}"
    cat <<-EOF
Commands:
---------
  build       -> Build Container
  publish     -> Push to Docker Registry
  teardown    -> Teardown Dev Container
  e2e         -> Build Dev Container,Run End to End IaaC Test Scripts and Teardown
EOF
    ;;
esac
