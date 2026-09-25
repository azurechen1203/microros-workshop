#!/usr/bin/env bash
# Start the micro-ROS workshop container.
# Usage: ./run.sh [serial_device] [ros_domain_id]
#   e.g. ./run.sh                     # /dev/ttyACM0, domain 0
#        ./run.sh /dev/ttyUSB0 17     # /dev/ttyUSB0, domain 17


IMAGE="microros-workshop:latest"
CONTAINER_NAME="microros_workshop"
DEVICE="${1:-/dev/ttyACM0}"
DOMAIN_ID="${2:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}/ros2_ws"
MICROROS_DIR="${SCRIPT_DIR}/microros_ws"

mkdir -p "${WORKSPACE_DIR}/src" "${MICROROS_DIR}"

# Replace any container left over from a previous run.
if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "Removing existing container '${CONTAINER_NAME}'..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null
fi

# Pass the ESP32 serial port through if it is plugged in.
DEVICE_FLAGS=()
if [ -e "${DEVICE}" ]; then
  DEVICE_FLAGS=(--device="${DEVICE}")
else
  echo "Warning: ${DEVICE} not found, continuing without it."
fi

# The container starts as root, gives rosuser the same user and group ID as
# the host user (so the mounted workspaces are writable), then drops to rosuser.
STARTUP='
  if [ "$(id -u rosuser)" != "${HOST_UID}" ] || [ "$(id -g rosuser)" != "${HOST_GID}" ]; then
    groupmod -o -g "${HOST_GID}" rosuser
    usermod -o -u "${HOST_UID}" rosuser
  fi
  exec su rosuser
'

docker run -it \
  --name "${CONTAINER_NAME}" \
  --user root \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  -e ROS_DOMAIN_ID="${DOMAIN_ID}" \
  -v "${WORKSPACE_DIR}:/home/rosuser/ros2_ws" \
  -v "${MICROROS_DIR}:/home/rosuser/microros_ws" \
  "${DEVICE_FLAGS[@]}" \
  -p 8888:8888/udp \
  "${IMAGE}" \
  bash -c "${STARTUP}"
