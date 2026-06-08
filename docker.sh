#!/bin/bash
set -euo pipefail

SITE=${1:-}
COMMAND=${2:-}
shift 2 2>/dev/null || true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker/compose.yaml"
SEED_COMPOSE_FILE="$SCRIPT_DIR/docker/compose.seed.yaml"
ENV_FILE="$SCRIPT_DIR/docker/default.env"

BUILD=false
FRESH=false
for arg in "$@"; do
    case "$arg" in
        --build) BUILD=true ;;
        --fresh) FRESH=true ;;
        *) echo "Unknown option: '$arg'"; echo ""; usage ;;
    esac
done

usage() {
    echo "Usage: $0 <site> <command> [options]"
    echo ""
    echo "Sites:    kgh-test | wellbody-demo | wellbody-gladi"
    echo "Commands: start | stop | update | build | logs | destroy"
    echo ""
    echo "Options:"
    echo "  --build   Build the distribution from source before starting"
    echo "  --fresh   Initialize OpenMRS from scratch instead of using a pre-seeded image"
    exit 1
}

case "$SITE" in
    kgh-test)       PIH_CONFIG="sierraLeone,sierraLeone-kgh,sierraLeone-kgh-test" ;;
    wellbody-demo)  PIH_CONFIG="sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-demo" ;;
    wellbody-gladi) PIH_CONFIG="sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-gladi" ;;
    *) echo "Unknown site: '$SITE'"; echo ""; usage ;;
esac

[ -z "$COMMAND" ] && usage

export PIH_CONFIG
export SERVICE_NAME="$SITE"
export SITE

BASE_COMPOSE="docker compose -f $COMPOSE_FILE --env-file $ENV_FILE"
SEED_COMPOSE="docker compose -f $SEED_COMPOSE_FILE --env-file $ENV_FILE"

build_image() {
    cd "$SCRIPT_DIR" && mvn clean package -U
    if ! $FRESH; then
        # compose.seed.yaml has no build context; build the image explicitly
        $BASE_COMPOSE build
    fi
}

start_stack() {
    if $FRESH; then
        $BASE_COMPOSE up -d
    else
        $SEED_COMPOSE up -d
    fi
}

case "$COMMAND" in
    start)
        if $BUILD; then build_image; fi
        start_stack
        ;;
    update)
        if $BUILD; then build_image; fi
        if $FRESH; then $BASE_COMPOSE down; else $SEED_COMPOSE down; fi
        start_stack
        ;;
    wait)
        OPENMRS_CONTAINER=$(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps -q openmrs)
        echo "Waiting for OpenMRS to initialize (up to 60 minutes)..."
        docker logs -f "$OPENMRS_CONTAINER" 2>&1 &
        LOGS_PID=$!
        for i in $(seq 1 120); do
            if docker logs "$OPENMRS_CONTAINER" 2>&1 | grep -q "Distribution startup complete"; then
                kill $LOGS_PID 2>/dev/null || true
                break
            fi
            sleep 30
            if [ "$i" -eq 120 ]; then
                kill $LOGS_PID 2>/dev/null || true
                echo "Timed out waiting for OpenMRS to initialize after 60 minutes"
                exit 1
            fi
        done
        echo "Waiting for OpenMRS to be accessible..."
        for i in $(seq 1 20); do
            if curl -sf "http://localhost:${TOMCAT_HTTP_PORT:-8080}/openmrs" > /dev/null 2>&1; then
                echo "OpenMRS is ready."
                exit 0
            fi
            sleep 15
        done
        echo "Timed out waiting for OpenMRS to become accessible"
        exit 1
        ;;
    build)
        cd "$SCRIPT_DIR" && mvn clean package -U
        $BASE_COMPOSE build
        ;;
    stop)    $SEED_COMPOSE down ;;
    logs)    $SEED_COMPOSE logs -f ;;
    destroy) $SEED_COMPOSE down -v ;;
    *) echo "Unknown command: '$COMMAND'"; echo ""; usage ;;
esac
