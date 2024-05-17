#!/bin/bash

# Function to check if docker-compose is available
function check_docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# Assign the correct command to DOCKER_COMPOSE_CMD
DOCKER_COMPOSE_CMD=$(check_docker_compose)
dock_base="Dockerfile.base"
dock_devel="Dockerfile.devel"

action="$1"

# -------------------------------------
# ------ BUILD
# -------------------------------------
if [ "$action" == "build" ]; then
  docker build --no-cache -t prestabase:latest -f $dock_base .
  docker build --no-cache -t prestadevel:latest -f $dock_devel .

# -------------------------------------
# ------ SERVICES BUILD DEPLOY
# -------------------------------------  

elif [ "$action" == "up" ]; then
  docker build --no-cache -t prestadevel:latest -f $dock_devel .
  $DOCKER_COMPOSE_CMD -p prestadevel up -d
fi

