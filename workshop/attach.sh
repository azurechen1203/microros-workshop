#!/usr/bin/env bash
# Open another shell, as rosuser, in the container started by run.sh.

CONTAINER_NAME="microros_workshop"

exec docker exec -it -u rosuser "${CONTAINER_NAME}" bash
