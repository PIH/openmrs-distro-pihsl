#!/bin/bash
set -euo pipefail

SITE=${1:-}
COMMAND=${2:-}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker/compose.yaml"
ENV_FILE="$SCRIPT_DIR/docker/default.env"

usage() {
    echo "Usage: $0 <site> <command>"
    echo ""
    echo "Sites:    kgh-test | wellbody-demo | wellbody-gladi"
    echo "Commands: start | stop | update | build | logs | destroy"
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

COMPOSE="docker compose -f $COMPOSE_FILE --env-file $ENV_FILE"

case "$COMMAND" in
    start)
        cd "$SCRIPT_DIR" && mvn clean package -U
        $COMPOSE up -d
        ;;
    update)
        cd "$SCRIPT_DIR" && mvn clean package -U
        $COMPOSE down && $COMPOSE up -d
        ;;
    build)
        cd "$SCRIPT_DIR" && mvn clean package -U
        $COMPOSE build
        ;;
    stop)    $COMPOSE down ;;
    logs)    $COMPOSE logs -f ;;
    destroy) $COMPOSE down -v ;;
    *) echo "Unknown command: '$COMMAND'"; echo ""; usage ;;
esac
