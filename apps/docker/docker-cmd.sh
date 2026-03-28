#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<EOF
Wrapper around the Docker deployment in this repository.

usage: $(basename "$0") ACTION [ARGS...]

actions:
EOF
    cat <<EOF | column -t -l2 -s'#'
> start:app             # Start the full stack in foreground
> start:app:d           # Start the full stack in detached mode
> pull                  # Pull the configured authserver/worldserver images
> down                  # Stop and remove the stack
> logs [SERVICE]        # Show compose logs, optionally for one service
> attach SERVICE        # Attach to worldserver/authserver console
> shell SERVICE         # Open a bash shell inside a running service
> db:shell              # Open a mysql shell inside the database container
> config                # Render the resolved compose configuration
> init                  # Re-run one-shot init services
> build                 # Explain how image builds are handled now
EOF
}

[[ $# -eq 0 ]] && usage && exit 0

action="$1"
shift || true

case "$action" in
    start:app)
        exec docker compose up
        ;;
    start:app:d)
        exec docker compose up -d
        ;;
    pull)
        exec docker compose pull authserver worldserver
        ;;
    down)
        exec docker compose down
        ;;
    logs)
        if [[ $# -gt 0 ]]; then
            exec docker compose logs -f "$1"
        fi
        exec docker compose logs -f
        ;;
    attach)
        [[ $# -ge 1 ]] || { echo "service name required"; exit 1; }
        exec docker compose attach "$1"
        ;;
    shell)
        [[ $# -ge 1 ]] || { echo "service name required"; exit 1; }
        exec docker compose exec "$1" bash
        ;;
    db:shell)
        exec docker compose exec database mysql -u root
        ;;
    config)
        exec docker compose config
        ;;
    init)
        exec docker compose up --force-recreate data-init db-prepare
        ;;
    build|build:nocache|prod:build|pull:prod|prod:pull|prod:up|prod:up:d|start:prod|start:prod:d|dev:up|dev:build|dev:dash|dev:shell|client-data|clean:build)
        cat <<EOF
This repository no longer uses the old local multi-profile Docker build flow.

Server images are expected to be built and published through the manual GitHub Actions workflow,
then referenced from the local .env file as WORLD_IMAGE and AUTH_IMAGE.

See: doc/DOCKER_CLASSIC_DEPLOYMENT_CN.md
EOF
        ;;
    *)
        usage
        exit 1
        ;;
esac
