# micro-ROS from Zero: Hands-On with ESP32

A ROSCon UK 2026 workshop introducing [micro-ROS](https://micro.ros.org/) on an ESP32. Please follow this file for setup before the workshop. The full step-by-step walkthrough used during the session lives in [HANDOUT.md](HANDOUT.md).

## Setup

> This workshop is written for Linux, where Docker's USB passthrough works natively. Windows can get there too, via WSL2 and `usbipd-win`, but it takes several manual steps, and the device needs to be reattached when switching between flashing firmware from the Arduino IDE and running the micro-ROS agent inside the container. macOS doesn't currently have a reliable equivalent. If you don't have a Linux machine, contact us before the workshop.

### Docker & Workshop Files

1. Install [Docker Engine](https://docs.docker.com/engine/install/) and confirm it's running
   ```bash
   sudo docker run hello-world
   ```
   > ⚠️ Install Docker Engine, not Docker Desktop. Docker Desktop for Linux runs containers inside a VM, so the ESP32's serial port can't be passed through to the container.

2. Add your user to the `docker` and `dialout` groups
   ```bash
   sudo usermod -aG docker $USER
   sudo usermod -aG dialout $USER
   ```
   > 📢 Log out and back in for both group changes to take effect

3. Clone this repo into your home directory
   ```bash
   git clone https://github.com/azurechen1203/microros-workshop.git ~/microros_workshop
   cd ~/microros_workshop/workshop
   ```
   > 📢 Clone it to exactly this path. Every command in the handout assumes `~/microros_workshop/workshop` so cloning it somewhere else means you'll have to manually translate every copy-pasted command during the workshop.

4. Get the image
   ```bash
   docker pull azurechen1203/microros-workshop:latest
   docker tag azurechen1203/microros-workshop:latest microros-workshop:latest
   ```
   The `tag` step matters as `run.sh` expects the image name `microros-workshop:latest`.

   Confirm it worked:
   ```bash
   docker images
   ```
   You should see `microros-workshop:latest` listed.

5. Build the micro-ROS agent
   > Everything from **b** onwards runs **inside the workshop container** (started in **a**), not on your own machine.

   **a.** Start the container
      ```bash
      cd ~/microros_workshop/workshop
      ./run.sh
      ```
      If the ESP32 isn't plugged in, you'll see `Warning: /dev/ttyACM0 not found, continuing without it.` This is expected at this stage, since the board isn't needed until the workshop.

   **b.** Create a micro-ROS workspace to host the setup tools
      ```bash
      cd ~/microros_ws
      git clone -b $ROS_DISTRO https://github.com/micro-ROS/micro_ros_setup.git src/micro_ros_setup
      ```

   **c.** Install dependencies and build
      ```bash
      sudo apt update && rosdep update
      rosdep install --from-paths src --ignore-src -y
      colcon build
      source install/local_setup.bash
      ```

   **d.** Create agent workspace
      ```bash
      ros2 run micro_ros_setup create_agent_ws.sh
      ```
      This prepares a nested workspace, including:
      - Transport layers (serial, UDP, etc.)
      - DDS middleware integration
      - micro_ros_agent executable

   **e.** Build the agent
      ```bash
      ros2 run micro_ros_setup build_agent.sh
      source install/local_setup.bash
      ```
      A `CMake Warning (dev)` about tinyxml2 may appear, and colcon then reports `1 package had stderr output`. This is harmless as long as you see `Finished <<< micro_ros_agent`.

   **f.** Verify the installation
      ```bash
      ros2 pkg list | grep micro_ros

      ## Expected output:
      # micro_ros_agent
      # micro_ros_msgs
      # micro_ros_setup
      ```

   **g.** Exit the container
      ```bash
      exit
      ```

   > 📢 The agent only needs to be built once. It lives in `workshop/microros_ws`, which is mounted from your machine, so it's still there the next time `run.sh` starts a fresh container at the workshop.

### Arduino IDE

1. Install the [Arduino IDE](https://support.arduino.cc/hc/en-us/articles/360019833020-Download-and-install-Arduino-IDE) (version 2, not the legacy 1.x line) on the same Linux machine as Docker. The ESP32 is flashed from the IDE and then talks to the agent in the container, so both need access to the same USB port.
   > ℹ️ The Linux download is an AppImage. [This guide](https://dev.to/lovestaco/how-to-create-a-launcher-for-your-appimage-on-linux-mc3) can be followed to create a desktop launcher for an AppImage, enabling the addition of a desktop icon for easier access.

2. Add ESP32 board support  
   Go to:
   **File > Preferences > Additional Board Manager URLs**  
   Add:
   ```text
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```

3. Install ESP32 board package  
   Go to:
   **Tools > Board > Boards Manager**  
   Install:
   **ESP32 by Espressif Systems**  
   Verify:
   **Tools > Board > esp32** appears

4. Install micro-ROS Arduino library  
   Download the precompiled micro-ROS library for Arduino IDE from [here](https://github.com/micro-ROS/micro_ros_arduino/releases)
   > ⚠️ Pick the release tagged for **Humble** (e.g. `v2.0.8-humble`), matching the ROS 2 distribution used in the workshop container. Releases for other distributions (Iron, Jazzy, Rolling, ...) won't be compatible with the agent.  

   Go to:
   **Sketch > Include Library > Add .ZIP Library** and select the downloaded file  

   Verify:
   **File > Examples > micro_ros_arduino** appears

> ⚠️ One-time per machine (unless you reinstall Arduino or the library). Both the ESP32 board support and the micro-ROS examples remain available afterward.

When the workshop starts, open [HANDOUT.md](HANDOUT.md) and continue from there.

## Repo Structure

```
~/microros_workshop/
├── README.md           # this file
├── HANDOUT.md          # full workshop walkthrough
└── workshop/
    ├── Dockerfile
    ├── run.sh           # start the workshop container
    ├── attach.sh        # open an extra shell into it
    ├── ros2_ws/         # ROS 2 workspace, built during the workshop
    ├── microros_ws/     # micro-ROS Agent workspace, built during setup, see above
    └── firmware/        # Arduino sketches written during the workshop
```

`firmware/` won't exist right after cloning; it's created during the workshop. `ros2_ws/` is created empty by `run.sh` above and stays that way until the workshop builds it out. `microros_ws/` is both created and fully built above, before the workshop.
