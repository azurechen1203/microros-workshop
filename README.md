# micro-ROS Workshop

A hands-on workshop for ROSCon 2026 introducing [micro-ROS](https://micro.ros.org/) on an ESP32: publishing/subscribing over serial and Wi-Fi, debugging a microcontroller client, and handling reconnection.

The full step-by-step walkthrough used during the session lives in [HANDOUT.md](HANDOUT.md). Please follow this file for setup before the workshop.

## Setup

1. Install [Docker](https://docs.docker.com/engine/install/) and confirm it's running
   ```bash
   docker run hello-world
   ```

2. Add your user to the `docker` and `dialout` groups
   ```bash
   sudo usermod -aG docker $USER
   sudo usermod -aG dialout $USER
   ```
   > 📢 Log out and back in for both group changes to take effect

3. Install the [Arduino IDE](https://support.arduino.cc/hc/en-us/articles/360019833020-Download-and-install-Arduino-IDE)
   > ℹ️ For Linux users, [this guide](https://dev.to/lovestaco/how-to-create-a-launcher-for-your-appimage-on-linux-mc3) can be followed to create a desktop launcher for an AppImage, enabling the addition of a desktop icon for easier access.

4. Clone this repo into your home directory
   ```bash
   git clone https://github.com/azurechen1203/microros-workshop.git ~/microros_workshop
   cd ~/microros_workshop/workshop
   ```
   > 📢 Clone it to exactly this path. Every command in the handout assumes `~/microros_workshop/workshop` — cloning it somewhere else means you'll have to mentally translate every copy-pasted command during the workshop.

5. Get the image
   1. **If you have internet:**
      ```bash
      docker pull azurechen1203/microros-workshop:latest
      docker tag azurechen1203/microros-workshop:latest microros-workshop:latest
      ```
      The `tag` step matters — `run.sh` expects the image name `microros-workshop:latest`.
   2. **If you don't have reliable internet:**
      Copy `microros-workshop.tar` from a USB stick into this folder, then:
      ```bash
      docker load -i microros-workshop.tar
      ```

   Either way, confirm it worked:
   ```bash
   docker images
   ```
   You should see `microros-workshop:latest` listed.

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
    ├── ros2_ws/         # ROS2 workspace, built during the workshop
    ├── microros_ws/     # microROS Agent workspace, built during the workshop
    └── firmware/        # Arduino sketches you write during the exercises
```

`ros2_ws/`, `microros_ws/`, and `firmware/` won't exist right after cloning — they're created during the workshop as you work through the exercises. See [HANDOUT.md](HANDOUT.md) for everything else.
