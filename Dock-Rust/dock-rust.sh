#!/usr/bin/env bash

set -e


ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


source "$ROOT_DIR/lib/colours.sh"
source "$ROOT_DIR/lib/banner.sh"


COMMAND=$1

shift


case "$COMMAND" in


    install)

        bash "$ROOT_DIR/commands/install.sh" "$@"

        ;;


    new)

        bash "$ROOT_DIR/commands/new.sh" "$@"

        ;;


    up)

        bash "$ROOT_DIR/commands/up.sh" "$@"

        ;;


    down)

        bash "$ROOT_DIR/commands/down.sh" "$@"

        ;;


    doctor)

        bash "$ROOT_DIR/commands/doctor.sh" "$@"

        ;;


    help|--help|-h)

        banner

        echo
        echo "Dock-Rust Commands"
        echo
        echo "  install              Install Dock-Rust"
        echo "  new                  Create a new project"
        echo "  up <name>            Start project containers"
        echo "  down <name>          Stop project containers"
        echo "  doctor               Check system requirements"
        echo

        ;;


    *)

        banner

        echo
        echo "Unknown command: $COMMAND"
        echo
        echo "Run:"
        echo
        echo "./dock-rust.sh help"
        echo

        exit 1

        ;;


esac