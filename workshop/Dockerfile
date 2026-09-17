# micro-ROS Workshop container
# Base: official ROS 2 image, ros-base variant (no GUI tools, just ros2/rclpy/colcon deps)

ARG ROS_DISTRO=humble
FROM ros:${ROS_DISTRO}-ros-base

ENV ROS_DISTRO=${ROS_DISTRO}

RUN apt-get update && apt-get install -y \
    python3-colcon-common-extensions \
    python3-rosdep \
    nano \
    sudo \
    && rosdep update \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for development and allow passwordless sudo
RUN useradd -m -s /bin/bash -G dialout rosuser && \
    echo "rosuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER rosuser
WORKDIR /home/rosuser

RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/rosuser/.bashrc

CMD ["/bin/bash"]
