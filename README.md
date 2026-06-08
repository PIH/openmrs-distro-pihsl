# PIH Sierra Leone EMR Distribution

This repository defines the OpenMRS distribution for PIH Sierra Leone. It packages together the PIH EMR parent distribution, Sierra Leone-specific content, and the PIH EMR frontend into a single deployable artifact.

## Components

| Component | Artifact |
|---|---|
| PIH EMR parent distro | `org.openmrs.distro:pihemr` |
| Sierra Leone content | `org.pih.openmrs:pihsl-content` |
| PIH EMR frontend | `org.pih.openmrs:openmrs-frontend-pihemr` |

Component versions are defined in `pom.xml` and resolved into `openmrs-distro.properties` at build time.

## Sites

| Site | PIH Config |
|---|---|
| `kgh-test` | `sierraLeone,sierraLeone-kgh,sierraLeone-kgh-test` |
| `wellbody-demo` | `sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-demo` |
| `wellbody-gladi` | `sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-gladi` |

## Developer Guide

### Prerequisites

- Java 8+
- Maven 3.x
- Docker

### Docker (`docker.sh`)

Use `docker.sh` to run a site locally using Docker Compose. The script builds the distribution, then manages the Docker stack.

```
./docker.sh <site> <command>
```

| Command | Description |
|---|---|
| `start` | Build the distro and start the stack |
| `update` | Rebuild and restart the stack |
| `build` | Build the distro and Docker image without starting |
| `stop` | Stop the running stack |
| `logs` | Tail container logs |
| `destroy` | Stop the stack and delete all volumes (wipes database) |

**Example:**
```bash
./docker.sh kgh-test start
```

The stack runs OpenMRS on port 8080 by default. Settings are in `docker/default.env` and can be overridden with shell environment variables.

**Example — run on a different port:**
```bash
TOMCAT_HTTP_PORT=9090 ./docker.sh kgh-test start
```

**Example — override the database root password:**
```bash
MYSQL_ROOT_PASSWORD=strongpassword ./docker.sh kgh-test start
```

To expose the database and Tomcat debug ports, edit `docker/default.env`:
```
COMPOSE_FILE=compose.yaml:compose.override.yaml
```

### OpenMRS SDK (`sdk.sh`)

Use `sdk.sh` to run a site using the [OpenMRS SDK](https://wiki.openmrs.org/display/docs/OpenMRS+SDK), which sets up a local Tomcat server with its own MySQL instance.

```
./sdk.sh <site> <command>
```

| Command | Description |
|---|---|
| `create` | Set up a new SDK server for the given site |
| `update` | Redeploy updated artifacts to an existing server |
| `run` | Start the server (Ctrl+C to stop) |
| `destroy` | Delete the server and all its data |

**Example — first-time setup:**
```bash
./sdk.sh kgh-test create
./sdk.sh kgh-test run
```

**Example — after updating component versions:**
```bash
./sdk.sh kgh-test update
./sdk.sh kgh-test run
```

#### Environment variable overrides

| Variable | Default | Description |
|---|---|---|
| `SERVER_ID` | site name | SDK server directory name |
| `SERVER_PORT` | `8080` | Tomcat HTTP port |
| `DEBUG_PORT` | `1044` | Remote debug port |
| `JMX_PORT` | _(disabled)_ | Enable JMX monitoring on this port |
| `DB_CONTAINER` | _(SDK-managed)_ | Connect to an existing Docker MySQL container |
| `DB_HOST` | `localhost` | Database host (when `DB_CONTAINER` is set) |
| `DB_PORT` | `3308` | Database port (when `DB_CONTAINER` is set) |
| `DB_NAME` | server ID | Database name |
| `DB_USER` | `root` | Database user |
| `DB_PASSWORD` | `root` | Database password |

**Example — run with JMX monitoring:**
```bash
JMX_PORT=9000 ./sdk.sh kgh-test run
```

**Example — connect to an existing Docker MySQL container:**
```bash
DB_CONTAINER=mysql56 DB_PORT=3306 ./sdk.sh kgh-test create
./sdk.sh kgh-test run
```

### Seeded Environments (`compose.seed.yaml`)

Nightly CI publishes pre-initialized seed images per site. Using `docker/compose.seed.yaml` skips the ~30-minute first-run initialization and starts a working environment in under 5 minutes.

**Start a seeded environment:**

```bash
SITE=kgh-test \
  PIH_CONFIG=sierraLeone,sierraLeone-kgh,sierraLeone-kgh-test \
  docker compose -f docker/compose.seed.yaml --env-file docker/default.env up -d
```

OpenMRS will be available at `http://localhost:8080/openmrs` once healthy.

Per-site values:

| Site | `SITE` | `PIH_CONFIG` |
|---|---|---|
| KGH test | `kgh-test` | `sierraLeone,sierraLeone-kgh,sierraLeone-kgh-test` |
| Wellbody demo | `wellbody-demo` | `sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-demo` |
| Wellbody GLADI | `wellbody-gladi` | `sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-gladi` |

**Stop and remove all data:**

```bash
SITE=kgh-test docker compose -f docker/compose.seed.yaml --env-file docker/default.env down -v
```

Omit `-v` to preserve volumes across restarts. A subsequent `up -d` will resume from the existing volumes rather than re-seeding.

**Pin to a specific version:**

```bash
SEED_IMAGE_TAG=1.0.0 SITE=kgh-test \
  PIH_CONFIG=sierraLeone,sierraLeone-kgh,sierraLeone-kgh-test \
  docker compose -f docker/compose.seed.yaml --env-file docker/default.env up -d
```

All other `docker/default.env` overrides (ports, memory limits, passwords) work the same as with `compose.yaml`.

## CI and Publishing

CI is handled by GitHub Actions. On every push to `main`, the [Build and deploy](.github/workflows/build-and-deploy.yml) workflow:

1. Builds and publishes the Maven artifact to [Maven Central](https://central.sonatype.com/artifact/org.pih.openmrs/pihsl-distro) as `org.pih.openmrs:pihsl-distro`.
2. Builds and pushes a multi-platform Docker image (amd64 + arm64) to Docker Hub at [`partnersinhealth/openmrs-distro-pihsl`](https://hub.docker.com/r/partnersinhealth/openmrs-distro-pihsl), tagged with both `latest` and the Maven project version.

A separate [Build seeded images](.github/workflows/build-seeded-images.yml) workflow runs nightly and publishes pre-initialized seed images to Docker Hub for each site:

| Image | Tags |
|---|---|
| [`partnersinhealth/openmrs-distro-pihsl-seed-kgh-test`](https://hub.docker.com/r/partnersinhealth/openmrs-distro-pihsl-seed-kgh-test) | `latest`, version |
| [`partnersinhealth/openmrs-distro-pihsl-seed-wellbody-demo`](https://hub.docker.com/r/partnersinhealth/openmrs-distro-pihsl-seed-wellbody-demo) | `latest`, version |
| [`partnersinhealth/openmrs-distro-pihsl-seed-wellbody-gladi`](https://hub.docker.com/r/partnersinhealth/openmrs-distro-pihsl-seed-wellbody-gladi) | `latest`, version |

See [Seeded Environments](#seeded-environments-composeseedyaml) above for usage.

A separate [Update Versions](.github/workflows/update-versions.yml) workflow runs hourly and automatically commits any available snapshot dependency updates to `main`.
