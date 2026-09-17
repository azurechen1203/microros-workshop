#!/usr/bin/env bash
# Use this alongside run.sh when needed

CONTAINER_NAME="microros_workshop"

exec docker exec -it "${CONTAINER_NAME}" bash
