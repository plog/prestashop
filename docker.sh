#!/bin/bash

mkdir -p logs/apache
mkdir -p logs/prestashop
mkdir -p loki/chunks
mkdir -p loki/index
mkdir -p grafana

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
echo "Using: $DOCKER_COMPOSE_CMD"
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
  $DOCKER_COMPOSE_CMD up -d

# -------------------------------------
# ------ SERVICES BUILD DEPLOY
# -------------------------------------  

elif [ "$action" == "restart" ]; then
  $DOCKER_COMPOSE_CMD down
  $DOCKER_COMPOSE_CMD stop prestashop
  $DOCKER_COMPOSE_CMD rm -f prestashop
  docker rmi -f prestadevel:latest
  docker build --no-cache -t prestadevel:latest -f $dock_devel .
  $DOCKER_COMPOSE_CMD up -d
fi