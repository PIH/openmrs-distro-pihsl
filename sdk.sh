#!/bin/bash
set -euo pipefail

SITE=${1:-}
COMMAND=${2:-}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# JVM memory settings
export MAVEN_OPTS="-Xms512m -Xmx2g"

# Server settings
SERVER_PORT="${SERVER_PORT:-8080}"
DEBUG_PORT="${DEBUG_PORT:-1044}"

# DB connection settings — used when DB_CONTAINER is set
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3308}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-root}"

usage() {
    echo "Usage: $0 <site> <command>"
    echo ""
    echo "Sites:    kgh-test | wellbody-demo | wellbody-gladi"
    echo "Commands: create | update | run | destroy"
    echo ""
    echo "  create   Set up a new SDK server for the given site"
    echo "  update   Redeploy updated artifacts to an existing server"
    echo "  run      Start the server (use Ctrl+C to stop)"
    echo "  destroy  Delete the server and all its data"
    echo ""
    echo "Environment variable overrides:"
    echo "  SERVER_ID     Server ID (default: site name)"
    echo "  SERVER_PORT   Tomcat port (default: 8080)"
    echo "  DEBUG_PORT    Remote debug port (default: 1044)"
    echo "  JMX_PORT      Enable JMX monitoring on this port (default: disabled)"
    echo ""
    echo "Database:"
    echo "  (default)     SDK creates and manages its own Docker MySQL container"
    echo "  DB_CONTAINER  Connect to an existing Docker container (e.g. DB_CONTAINER=mysql56)"
    echo "  DB_HOST       Database host (default: localhost)"
    echo "  DB_PORT       Database port (default: 3308)"
    echo "  DB_NAME       Database name (default: server ID)"
    echo "  DB_USER       Database user (default: root)"
    echo "  DB_PASSWORD   Database password (default: root)"
    exit 1
}

case "$SITE" in
    kgh-test)       PIH_CONFIG="sierraLeone,sierraLeone-kgh,sierraLeone-kgh-test" ;;
    wellbody-demo)  PIH_CONFIG="sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-demo" ;;
    wellbody-gladi) PIH_CONFIG="sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-gladi" ;;
    *) echo "Unknown site: '$SITE'"; echo ""; usage ;;
esac

[ -z "$COMMAND" ] && usage

SERVER_ID="${SERVER_ID:-${SITE}}"
SERVER_DIR="$HOME/openmrs/${SERVER_ID}"  # used by destroy
DB_NAME="${DB_NAME:-${SERVER_ID}}"
DB_URI="jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?autoReconnect=true&useUnicode=true&characterEncoding=UTF-8&sessionVariables=default_storage_engine%3DInnoDB"

SETUP_PARAMS=(
    "-DserverId=${SERVER_ID}"
    "-Dpih.config=${PIH_CONFIG}"
    "-DserverPort=${SERVER_PORT}"
    "-Ddebug=${DEBUG_PORT}"
)

if [ -n "${DB_CONTAINER:-}" ]; then
    # Connect to an existing Docker container — wizard selects it, then we provide container/user/pass via batchAnswers
    # -DdbUri is passed so the URI prompt is skipped (promptForValueIfMissingWithDefault returns early)
    SETUP_PARAMS+=(
        "-DdbUri=${DB_URI}"
        "-DbatchAnswers=Existing docker container (requires pre-installed Docker),${DB_CONTAINER},${DB_USER},${DB_PASSWORD}"
    )
else
    # SDK creates and manages its own Docker MySQL container
    # Must go through the wizard (batchAnswers) so promptForDockerizedSdkMysql runs and sets the URI/credentials
    SETUP_PARAMS+=("-DbatchAnswers=MySQL 8.4.1 and above in SDK docker container (requires pre-installed Docker)")
fi

if [ -n "${JAVA_HOME:-}" ]; then
    SETUP_PARAMS+=("-DjavaHome=${JAVA_HOME}")
fi

cd "$SCRIPT_DIR"

case "$COMMAND" in
    create)
        mvn clean package -U
        mvn openmrs-sdk:setup -Ddistro="${SCRIPT_DIR}/target/classes/openmrs-distro.properties" "${SETUP_PARAMS[@]}"
        ;;
    update)
        mvn clean package -U
        mvn openmrs-sdk:deploy -Ddistro="${SCRIPT_DIR}/target/classes/openmrs-distro.properties" -DserverId="${SERVER_ID}"
        ;;
    run)
        # Set JMX_PORT to enable JMX remote monitoring (e.g. JMX_PORT=9000 ./sdk.sh kgh-test run)
        if [ -n "${JMX_PORT:-}" ]; then
            MAVEN_OPTS="${MAVEN_OPTS} -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=${JMX_PORT} -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
        fi
        mvn openmrs-sdk:run -DserverId="${SERVER_ID}"
        ;;
    destroy)
        echo "This will permanently delete ${SERVER_DIR} and all its data."
        read -r -p "Are you sure? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
        rm -rf "${SERVER_DIR}"
        echo "Deleted ${SERVER_DIR}"
        ;;
    *) echo "Unknown command: '$COMMAND'"; echo ""; usage ;;
esac
