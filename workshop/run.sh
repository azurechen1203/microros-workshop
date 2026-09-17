#!/usr/bin/env bash
# Run the micro-ROS workshop container.

IMAGE="microros-workshop:latest"
CONTAINER_NAME="microros_workshop"
DEVICE="${1:-/dev/ttyACM0}"
DOMAIN_ID="${2:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}/ros2_ws"
MICROROS_DIR="${SCRIPT_DIR}/microros_ws"
CONTAINER_WORKSPACE_DIR="/home/rosuser/microros_workshop"

mkdir -p "${WORKSPACE_DIR}" "${MICROROS_DIR}"

# Remove any stale container from a previous run so the new mount layout is applied.
if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "Removing existing container '${CONTAINER_NAME}'..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

DEVICE_FLAGS=()
if [ -e "${DEVICE}" ]; then
  DEVICE_FLAGS=(--device="${DEVICE}")
else
  echo "Warning: ${DEVICE} not found, continuing without it."
fi

docker run -it \
  --name "${CONTAINER_NAME}" \
  -e ROS_DOMAIN_ID="${DOMAIN_ID}" \
  -v "${WORKSPACE_DIR}:${CONTAINER_WORKSPACE_DIR}/ros2_ws" \
  -v "${MICROROS_DIR}:${CONTAINER_WORKSPACE_DIR}/microros_ws" \
  "${DEVICE_FLAGS[@]}" \
  -p 8888:8888/udp \
  "${IMAGE}"
