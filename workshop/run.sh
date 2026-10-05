#!/usr/bin/env bash
# Start the micro-ROS workshop container.
# Usage: ./run.sh [ros_domain_id]
#        ./run.sh        # domain 0
#        ./run.sh 17     # domain 17

IMAGE="microros-workshop:latest"
CONTAINER_NAME="microros_workshop"
DOMAIN_ID="${1:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${SCRIPT_DIR}/ros2_ws"
MICROROS_DIR="${SCRIPT_DIR}/microros_ws"

# Workspaces live on the host and are mounted in, so they survive restarts.
mkdir -p "${WORKSPACE_DIR}/src" "${MICROROS_DIR}"

# Stop if the image hasn't been pulled and tagged.
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "Image '${IMAGE}' not found. Follow step 4 of the README to pull and tag it."
  exit 1
fi

# Start from a fresh container every time.
if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "Removing existing container '${CONTAINER_NAME}'..."
  docker rm -f "${CONTAINER_NAME}" >/dev/null
fi

# Host group that owns the USB serial ports, passed in so rosuser can open them.
SERIAL_GID="$(stat -c %g /dev/ttyACM* /dev/ttyUSB* 2>/dev/null | head -n 1)"
if [ -z "${SERIAL_GID}" ]; then
  SERIAL_GID="$(getent group dialout | cut -d: -f3)"
  echo "No board found yet. You can plug it in after the container starts."
fi

# Runs as root when the container starts, then switches to rosuser:
#   1. match rosuser's user and group IDs to the host user, so files in the
#      mounted workspaces stay owned by you
#   2. match the container's dialout group to the host serial port group
STARTUP='
  if [ "$(id -u rosuser)" != "${HOST_UID}" ] || [ "$(id -g rosuser)" != "${HOST_GID}" ]; then
    groupmod -o -g "${HOST_GID}" rosuser
    usermod -o -u "${HOST_UID}" rosuser
  fi
  if [ -n "${SERIAL_GID}" ] && [ "$(getent group dialout | cut -d: -f3)" != "${SERIAL_GID}" ]; then
    groupmod -o -g "${SERIAL_GID}" dialout
  fi
  exec su rosuser
'

# /dev is shared with the host so the board can be plugged in at any time.
# Device access is limited to USB serial ports: 166 = ttyACM*, 188 = ttyUSB*.
docker run -it \
  --name "${CONTAINER_NAME}" \
  --user root \
  -e HOST_UID="$(id -u)" \
  -e HOST_GID="$(id -g)" \
  -e SERIAL_GID="${SERIAL_GID}" \
  -e ROS_DOMAIN_ID="${DOMAIN_ID}" \
  -v "${WORKSPACE_DIR}:/home/rosuser/ros2_ws" \
  -v "${MICROROS_DIR}:/home/rosuser/microros_ws" \
  -v /dev:/dev \
  --device-cgroup-rule='c 166:* rmw' \
  --device-cgroup-rule='c 188:* rmw' \
  -p 8888:8888/udp \
  "${IMAGE}" \
  bash -c "${STARTUP}"
