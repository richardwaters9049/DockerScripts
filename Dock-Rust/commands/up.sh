#!/usr/bin/env bash

set -e


ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROJECTS_DIR="$ROOT_DIR/Projects"


source "$ROOT_DIR/lib/colours.sh"
source "$ROOT_DIR/lib/banner.sh"


banner


PROJECT_NAME=$1


if [ -z "$PROJECT_NAME" ]; then

    echo -e "${RED}❌ No project supplied${RESET}"
    echo
    echo "Usage:"
    echo
    echo "./dock-rust.sh up <project-name>"
    exit 1

fi


PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"


if [ ! -d "$PROJECT_PATH" ]; then

    echo -e "${RED}❌ Project not found:${RESET}"
    echo "$PROJECT_PATH"
    exit 1

fi


if [ ! -f "$PROJECT_PATH/docker-compose.yml" ]; then

    echo -e "${RED}❌ docker-compose.yml missing${RESET}"
    exit 1

fi


cd "$PROJECT_PATH"


echo -e "${CYAN}Starting project:${RESET} $PROJECT_NAME"
echo


if ! docker info >/dev/null 2>&1; then

    echo -e "${RED}❌ Docker daemon is not running${RESET}"
    exit 1

fi


echo -e "${CYAN}Building containers...${RESET}"

docker compose up -d --build


echo

echo -e "${CYAN}Checking services...${RESET}"

sleep 3


docker compose ps


echo

echo -e "${GREEN}Dock-Rust environment ready${RESET}"

echo

echo "Frontend:"
echo "http://localhost:3000"

echo

echo "Backend:"
echo "http://localhost:8000"

echo

echo "Database:"
echo "localhost:5432"

echo

echo "Redis:"
echo "localhost:6379"