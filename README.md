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

## Running on Windows

This section walks through how to run a local OpenMRS instance on a Windows machine — no programming experience required.

### What you need

- Windows 10 (version 2004 or later) or Windows 11
- At least 8 GB RAM (16 GB recommended — OpenMRS uses a lot of memory)
- A reliable internet connection for the initial download

### One-time setup

**Step 1 — Install Windows Subsystem for Linux**

Open PowerShell in administrator mode by right-clicking and selecting "Run as administrator" and enter the following command:

```powershell
wsl --install
```

Reboot your computer.

**Step 2 — Install Git and download the scripts**

Open the Ubuntu terminal from your start menu and paste the following commands one at a time and press Enter after each:

```bash
sudo apt-get update && sudo apt-get install -y git
```

```bash
git clone https://github.com/PIH/openmrs-distro-pihsl.git
cd openmrs-distro-pihsl
```

**Step 3 — Install docker

Run the setup script included in the repo to install docker. This will ask for your ubuntu password.

```bash
./setup.sh
```

When the process is complete, close the Ubuntu terminal window and relaunch it from the Start Menu.
You only need to do this once. The `openmrs-distro-pihsl` folder now contains everything needed to run the environment.

### Starting an environment

In the Ubuntu terminal (make sure you are inside the `openmrs-distro-pihsl` folder), run the command for the site you want:

| Site           | Command |
|----------------|---|
| KGH Test       | `./docker.sh kgh-test start` |
| Wellbody Demo  | `./docker.sh wellbody-demo start` |
| Wellbody Gladi | `./docker.sh wellbody-gladi start` |

The first time you start a site, Docker will download the pre-initialized image from the internet. This can take 10–20 minutes depending on your connection. Subsequent starts will be much faster.

Once the download is complete, run the matching wait command to be notified when OpenMRS is fully ready:

| Site           | Command |
|----------------|---|
| KGH Test       | `./docker.sh kgh-test wait` |
| Wellbody Demo  | `./docker.sh wellbody-demo wait` |
| Wellbody Gladi | `./docker.sh wellbody-gladi wait` |

When you see **OpenMRS is ready**, open a browser and go to:

**http://localhost:8080/openmrs**

### Stopping

When you are done, stop the environment to free up memory. Your data is preserved and will be there when you start again.

```bash
./docker.sh kgh-test stop
```

To wipe all data and start completely fresh next time:

```bash
./docker.sh kgh-test destroy
```

### Keeping the scripts up to date

Periodically run the following in the Ubuntu terminal from inside the `openmrs-distro-pihsl` folder to pick up any script updates:

```bash
git pull
```

### Troubleshooting

**"Docker is not running" or similar error**
Make sure Docker Desktop is open and the whale icon in the system tray is steady before running any commands.

**OpenMRS runs very slowly or runs out of memory**
Docker Desktop limits how much memory it can use by default. Open Docker Desktop, go to **Settings → Resources → Memory**, and increase it to at least 6 GB. Click **Apply & restart**.

**"Permission denied" when running `./docker.sh`**
Run this once to make the script executable:
```bash
chmod +x docker.sh
```


## Developer Guide

### Prerequisites

- Java 8+
- Maven 3.x
- Docker

### Docker (`docker.sh`)

Use `docker.sh` to run a site locally using Docker Compose.

```
./docker.sh <site> <command> [options]
```

| Command | Description |
|---|---|
| `start` | Start the stack |
| `wait` | Wait for OpenMRS to finish initializing |
| `update` | Restart the stack, pulling the latest image |
| `build` | Build the distribution from source and create a local Docker image |
| `stop` | Stop the running stack |
| `logs` | Tail container logs |
| `destroy` | Stop the stack and delete all volumes (wipes database) |

| Option | Description |
|---|---|
| `--build` | Build the distribution from source before starting |
| `--fresh` | Initialize OpenMRS from scratch instead of using a pre-seeded image |

By default, `start` and `update` use a [pre-seeded image](#seeded-environments-composeseedyaml) for fast startup (~5 minutes). Pass `--fresh` to initialize from scratch (~30 minutes).

**Example — start with pre-seeded image (default):**
```bash
./docker.sh kgh-test start
```

**Example — build from source and start:**
```bash
./docker.sh kgh-test start --build
```

**Example — initialize from scratch:**
```bash
./docker.sh kgh-test start --fresh
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

Nightly CI publishes pre-initialized seed images per site. `docker.sh start` uses these by default, skipping the ~30-minute first-run initialization so the stack is ready in under 5 minutes.

For programmatic or downstream use, invoke `docker/compose.seed.yaml` directly. `SITE` is the only required variable; `PIH_CONFIG` is resolved automatically by `docker.sh` but must be set explicitly when using compose directly.

| Site | `SITE` | `PIH_CONFIG` |
|---|---|---|
| KGH test | `kgh-test` | `sierraLeone,sierraLeone-kgh,sierraLeone-kgh-test` |
| Wellbody demo | `wellbody-demo` | `sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-demo` |
| Wellbody GLADI | `wellbody-gladi` | `sierraLeone,sierraLeone-wellbody,sierraLeone-wellbody-gladi` |

```bash
SITE=kgh-test \
  PIH_CONFIG=sierraLeone,sierraLeone-kgh,sierraLeone-kgh-test \
  docker compose -f docker/compose.seed.yaml --env-file docker/default.env up -d
```

To pin to a specific version, set `SEED_IMAGE_TAG=1.0.0`. To remove all volumes for a clean re-seed, pass `-v` to `down`.

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
