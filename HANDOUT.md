# micro-ROS Workshop Handout

> Make sure you've completed the setup in [README.md](README.md) first — Docker, Arduino IDE, the repo clone, and the workshop image should all be ready before you start here.

## Workshop Setup

Everything in this section runs **on your own machine**, before you enter the container. Once you start the container (step 2), everything from Step 1 onward runs **inside** it.

1. Check your ESP32's serial port
   Plug in the board, then:
   ```bash
   ls /dev/tty*
   ```
   Look for something like `/dev/ttyACM0` or `/dev/ttyUSB0`. If it's not `/dev/ttyACM0`, pass it as the first argument when you start the container in the next step.

2. Start the container
   ```bash
   cd ~/microros_workshop/workshop
   ./run.sh                    # /dev/ttyACM0, domain 0
   ./run.sh /dev/ttyUSB0       # different serial port
   ./run.sh /dev/ttyACM0 17    # set domain ID to 17
   ```
   This mounts `ros2_ws/` and `microros_ws/` into the container, publishes the UDP port for the Wi-Fi exercises, and attaches the ESP32's serial port if found (warns and continues without it if not).

3. Second terminal, when you need one
   ```bash
   cd ~/microros_workshop/workshop
   ./attach.sh
   ```
   Opens another shell into the same running container — useful for running the agent in one terminal while a node runs in another. This is a **new** terminal window, so it starts in your home directory — the `cd` above is needed even if you already ran `run.sh` in another tab.


## Step1: ROS2

1. Create a ROS2 package led_demo
   ```bash
   cd ~/microros_workshop/ros2_ws/src
   ros2 pkg create led_demo --build-type ament_python
   ```

2. Create a script
   ```bash
   cd ~/microros_workshop/ros2_ws/src/led_demo/led_demo
   touch led_control.py
   nano led_control.py
   ```
   `led_control.py` - REMEMBER to set your own namespace
   ```python
   import rclpy
   from rclpy.node import Node
   from std_msgs.msg import Int32

   class LedControlNode(Node):
       def __init__(self):
           super().__init__('led_controller', namespace='hyc')
           self.publisher_ = self.create_publisher(Int32, 'led_control', 10)
           self.subscriber_ = self.create_subscription(Int32, 'led_status', self.status_callback, 1)
           self.latest_status = None
           self.cmd_labels = {0: 'off', 1: 'on'}

       def status_callback(self, msg: Int32):
           self.latest_status = msg.data

       def publish_cmd(self, cmd: int):
           if cmd not in self.cmd_labels:
               raise ValueError('Unsupported command code: %s' % cmd)
           msg = Int32()
           msg.data = cmd
           self.publisher_.publish(msg)
           self.get_logger().info('Sent control command: %s' % self.cmd_labels[cmd])


   def main(args=None):
       rclpy.init(args=args)
       node = LedControlNode()

       try:
           while rclpy.ok():
               rclpy.spin_once(node, timeout_sec=0.1)
               print('\n=== LED Menu ===')
               print('0. off, 1. on, 2. status, 3. exit')
               raw_choice = input('Enter your choice: ').strip()

               try:
                   choice = int(raw_choice)
               except ValueError:
                   choice = None

               if choice in (0, 1):
                   node.publish_cmd(choice)
               elif choice == 2:
                   rclpy.spin_once(node, timeout_sec=0)
                   print(f'LED Status: {node.latest_status}')
               elif choice == 3:
                   break
               else:
                   print('Invalid choice. Please enter a number between 0 and 3.')
       except KeyboardInterrupt:
           pass
       finally:
           node.destroy_node()
           rclpy.shutdown()


   if __name__ == '__main__':
       main()
   ```
   This node:
   - Publishes LED commands to /led_control
   - Subscribes to /led_status
   - Provides a simple CLI menu for interaction

3. Update setup.py to register the script as an executable
   ```bash
   cd ~/microros_workshop/ros2_ws/src/led_demo
   nano setup.py
   ```
   Add the following line to `entry_points`
   ```python
   entry_points={
       'console_scripts': [
           'led_control = led_demo.led_control:main'
       ],
   },
   ```

4. Build the workspace
   ```bash
   cd ~/microros_workshop/ros2_ws
   colcon build
   source install/setup.bash
   ```

5. Run the ROS2 node
   Terminal #1:
   ```bash
   ros2 run led_demo led_control
   ```
   Terminal #2:
   ```bash
   # Verify the namespace
   ros2 node list
   ros2 topic list
   ```

6. Terminate all the terminals before moving on

## Step 2: microROS Agent Setup

> Run everything in this step **inside the container**, not on your own machine.

1. Create a microROS workspace to host the setup tools
   ```bash
   cd ~/microros_workshop/microros_ws
   git clone -b $ROS_DISTRO https://github.com/micro-ROS/micro_ros_setup.git src/micro_ros_setup
   ```

2. Install dependencies and build
   ```bash
   sudo apt update && rosdep update
   rosdep install --from-paths src --ignore-src -y
   colcon build
   source install/local_setup.bash
   ```

3. Create agent workspace
   ```bash
   ros2 run micro_ros_setup create_agent_ws.sh
   ```
   This prepares a nested workspace, including:
   - Transport layers (serial, UDP, etc.)
   - DDS middleware integration
   - micro_ros_agent executable

4. Build the agent
   ```bash
   ros2 run micro_ros_setup build_agent.sh
   source install/local_setup.bash
   ```
   A `CMake Warning (dev)` about tinyxml2 may appear, and colcon then reports `1 package had stderr output`. This is harmless as long as you see `Finished <<< micro_ros_agent`.

5. Verify the installation
   ```bash
   ros2 pkg list | grep micro_ros

   ## Expected output:
   # micro_ros_agent
   # micro_ros_msgs
   # micro_ros_setup
   ```

> ⚠️ **micro-ROS Agent Setup Note**
> The agent only needs to be built once (or when updating/rebuilding the workspace).
>
> In new terminals, only the ROS 2 and workspace environments need to be sourced:
>
> ```bash
> source /opt/ros/$ROS_DISTRO/setup.bash
> source ~/microros_workshop/microros_ws/install/local_setup.bash
> ```

## Step 3: microROS Client Setup (Arduino IDE)

1. Add ESP32 board support
   Go to:
   **File → Preferences → Additional Board Manager URLs**
   Add:
   ```text
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```

2. Install ESP32 board package
   Go to:
   **Tools → Board → Boards Manager**
   Install:
   **ESP32 by Espressif Systems**
   Verify:
   **Tools → Board → esp32 boards appear**

3. Install microROS Arduino library
   Download precompiled micro-ROS library for arduino IDE from [here](https://github.com/micro-ROS/micro_ros_arduino/releases)
   Go to:
   **Sketch > Include Library > Add .ZIP Library** and select the downloaded file  

   Verify:
   **File → Examples → micro_ros_arduino appears**

> ⚠️ **micro-ROS Arduino Setup Note**
>
> This setup is one-time per machine (unless you reinstall Arduino or the library).
>
> After installation, both ESP32 support and micro-ROS examples remain available.

## Step4: microROS Client

1. Open an example file
   Go to:
   **File > Examples > micro_ros_arduino > micro-ros_subscriber**

2. Configure LED pin
   ```cpp
   #define LED_PIN RGB_BUILTIN
   ```

3. Add the namespace to the node
   ```c
   RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));
   ```

4. Select board and port
   - Board: Adafruit QT Py ESP32 or ESP32 Dev Module
   - Port: /dev/ttyACM* or similar

5. Upload the code
   > 🔎 After uploading:
   >
   > 1. Observe LED on the ESP32 → What does it mean?
   >
   > 2. Verify the node and subscriber that have been set up in microROS client
   >    ```bash
   >    ros2 node list
   >    ros2 topic list
   >    ```

6. Open the terminal #1 and run the microROS agent
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   > 🤔 **Think:**
   >
   > 1. Why does the LED still blink after starting the agent?
   >
   > 2. Why are the ROS 2 nodes still missing?

7. Test communication
   Terminal #2:
   ```bash
   ros2 topic echo /hyc/micro_ros_arduino_subscriber
   ```
   Terminal #3:
   ```bash
   ros2 topic pub /hyc/micro_ros_arduino_subscriber std_msgs/msg/Int32 "data: 1"
   ```

## File System Overview

```
microros_workshop/                  (what `git clone` created)
├── README.md
├── HANDOUT.md
└── workshop/
    ├── Dockerfile
    ├── run.sh
    ├── attach.sh
    ├── firmware/                   # microROS Client — Arduino sketches
    │   ├── exercise1/
    │   │   └── exercise1.ino
    │   └── exercise2/
    │       └── exercise2.ino
    ├── ros2_ws/                    # ROS2 package (built in Step 1)
    │   ├── src/
    │   │   └── led_demo/
    │   ├── build/
    │   ├── install/
    │   └── log/
    └── microros_ws/                # microROS Agent (built in Step 2)
```

> ℹ️ `firmware/` doesn't exist yet either — Arduino IDE creates it the first time you use **File → Save As** in Exercise 1.


## Exercise 1: LED Control (Subscriber)

1. Save the file as exercise1

2. Change the error loop LED colour to red to distinguish states
   ```cpp
   void error_loop(){
     while(1){
       rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);  // Red
       delay(100);
     }
   }
   ```

3. Update the subscription callback
   ```cpp
   void subscription_callback(const void * msgin)
   {  
     const std_msgs__msg__Int32 * msg = (const std_msgs__msg__Int32 *)msgin;

     int cmd = msg->data;

     if(cmd == 0){
       digitalWrite(LED_PIN, LOW);
     } else if(cmd == 1){
       digitalWrite(LED_PIN, HIGH);
     }
   }
   ```

4. Update the subscriber topic
   ```cpp
     RCCHECK(rclc_subscription_init_default(
       &subscriber,
       &node,
       ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
       "led_control"));
   ```

5. Upload the code
   > ⚠️ Remember to stop microROS agent in the terminal otherwise “serial exception error” will show up

6. Run microROS agent and ROS2 node:
   Terminal #1:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```

> 🤔 It’s kind of annoying to stop the agent and re-run it again and hit the reset button

<details>
<summary>Solution</summary>

```c
#include <micro_ros_arduino.h>

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

#define LED_PIN RGB_BUILTIN

#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){error_loop();}}
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}


void error_loop(){
  while(1){
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);
    delay(100);
  }
}

void subscription_callback(const void * msgin)
{  
  const std_msgs__msg__Int32 * msg = (const std_msgs__msg__Int32 *)msgin;
  
  int cmd = msg->data;

  if(cmd == 0){
    digitalWrite(LED_PIN, LOW);
  } else if(cmd == 1){
    digitalWrite(LED_PIN, HIGH);
  }
}

void setup() {
  set_microros_transports();
  
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);  
  
  delay(2000);

  allocator = rcl_get_default_allocator();

  //create init_options
  RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));

  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));

  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 1, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
}

void loop() {
  delay(100);
  RCCHECK(rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100)));
}
```

</details>

## Exercise 2: Monitor LED Status (Publisher)

1. Save the file as exercise2

2. Open the example file:
   File > Examples > micro_ros_arduino > micro-ros_publisher

3. Copy required publisher and timer structure. Here are some hints:
   - Declaration for both publisher and message variable (e.g. status_msg)
   - Define timer_callback().
     - Read the status of LED
       ```cpp
       status_msg.data = (digitalRead(LED_PIN) == HIGH) ? 1 : 0;
       ```
     - Remember to change message variable in rcl_publish to what has been set in the declaration (e.g. status_msg).
   - Create publisher with topic named led_status
   - Create timer
   - Create executor and remember to increase the number of executor in rclc_executor_init

4. Upload the code

5. Run microROS agent and ROS2 node:
   Terminal #1:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   > 📢 Remember to reset the board
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```
   Terminal #3:
   ```bash
   ros2 topic echo /hyc/led_status
   ```

<details>
<summary>Solution</summary>

```cpp
#include <micro_ros_arduino.h>

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rcl_publisher_t publisher;
std_msgs__msg__Int32 status_msg;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

#define LED_PIN RGB_BUILTIN

#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){error_loop();}}
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}


void error_loop(){
  while(1){
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);  // Red
    delay(100);
  }
}

void timer_callback(rcl_timer_t * timer, int64_t last_call_time)
{  
  RCLC_UNUSED(last_call_time);
  if (timer != NULL) {
    status_msg.data = (digitalRead(LED_PIN) == HIGH) ? 1 : 0;
    RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));
  }
}

void subscription_callback(const void * msgin)
{  
  const std_msgs__msg__Int32 * msg = (const std_msgs__msg__Int32 *)msgin;
  int cmd = msg->data;

  if(cmd == 0){
    digitalWrite(LED_PIN, LOW);
  } else if(cmd == 1){
    digitalWrite(LED_PIN, HIGH);
  }
}

void setup() {
  set_microros_transports();
  
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);  
  
  delay(2000);

  allocator = rcl_get_default_allocator();

  //create init_options
  RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));

  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_status"));
    
  // create timer,
  const unsigned int timer_timeout = 1000;
  RCCHECK(rclc_timer_init_default(
    &timer,
    &support,
    RCL_MS_TO_NS(timer_timeout),
    timer_callback));

  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 2, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
  RCCHECK(rclc_executor_add_timer(&executor, &timer));

}

void loop() {
  delay(100);
  RCCHECK(rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100)));
}
```

</details>

## Exercise 3: Work with Strings

1. Save the file as exercise3

2. Change message type by:
   Add library
   ```cpp
   #include <std_msgs/msg/string.h>
   ```
   Change the message type to string and declare the buffer size
   ```cpp
   std_msgs__msg__String status_msg;
   char status_msg_buf[4];
   ```

3. Update timer_callback()
   ```cpp
   void timer_callback(rcl_timer_t * timer, int64_t last_call_time)
   {  
     RCLC_UNUSED(last_call_time);
     if (timer != NULL) {

       int led_state = digitalRead(RGB_BUILTIN);
       const char* s = (led_state == HIGH) ? "on" : "off";
       strcpy(status_msg.data.data, s);
       status_msg.data.size = strlen(s);  

       RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));
     }
   }
   ```

4. Initialise string buffer and update publisher message type in setup()
   ```cpp
     // initiatialise internal string buffer
     std_msgs__msg__String__init(&status_msg);
     status_msg.data.data = status_msg_buf;
     status_msg.data.capacity = sizeof(status_msg_buf);
     status_msg.data.size = 0;

     // create publisher
     RCCHECK(rclc_publisher_init_default(
       &publisher,
       &node,
       ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
       "led_status"));
   ```

5. Upload the code

6. Update ROS2 node led_control.py
   ```python
     from std_msgs.msg import String


     def __init__(self):
         super().__init__('led_controller', namespace='hyc')

         self.publisher_ = self.create_publisher(Int32, 'led_control', 10)
         self.subscriber_ = self.create_subscription(String, 'led_status', self.status_callback, 1)
         self.latest_status = None
         self.cmd_labels = {0: 'off', 1: 'on'}

     def status_callback(self, msg: String):
         self.latest_status = msg.data
   ```

7. Build the workspace
   ```bash
   cd ~/microros_workshop/ros2_ws
   colcon build
   source install/setup.bash
   ```

8. Run microROS agent and ROS2 node:
   Terminal #1:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   > 📢 Remember to reset the board
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```
   Terminal #3:
   ```bash
   ros2 topic echo /hyc/led_status
   ```

<details>
<summary>Solution</summary>

```cpp
#include <micro_ros_arduino.h>

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/string.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rcl_publisher_t publisher;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

std_msgs__msg__String status_msg;
char status_msg_buf[4];

#define LED_PIN RGB_BUILTIN

#define RCCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) { error_loop(); } \
  }
#define RCSOFTCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) {} \
  }


void error_loop() {
  while (1) {
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);
    delay(100);
  }
}

void subscription_callback(const void *msgin) {
  const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;

  int cmd = msg->data;

  if (cmd == 0) {
    digitalWrite(LED_PIN, LOW);
  } else if (cmd == 1) {
    digitalWrite(LED_PIN, HIGH);
  }
}

void timer_callback(rcl_timer_t *timer, int64_t last_call_time) {
  RCLC_UNUSED(last_call_time);
  if (timer != NULL) {
    
    int led_state = digitalRead(RGB_BUILTIN);
    const char* s = (led_state == HIGH) ? "on" : "off";
    strcpy(status_msg.data.data, s);
    status_msg.data.size = strlen(s);  

    RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

  }
}

void setup() {
  set_microros_transports();

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  delay(2000);

  allocator = rcl_get_default_allocator();

  //create init_options
  RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));

  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));
  
  // initiatialise internal string buffer
  std_msgs__msg__String__init(&status_msg);
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer,
  const unsigned int timer_timeout = 1000;
  RCCHECK(rclc_timer_init_default(
    &timer,
    &support,
    RCL_MS_TO_NS(timer_timeout),
    timer_callback));


  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 2, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
  RCCHECK(rclc_executor_add_timer(&executor, &timer));

}

void loop() {
  delay(100);
  RCCHECK(rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100)));
}
```

</details>

## Exercise 4: Debugging - Serial Output

1. Save the file as exercise4

2. Initialise serial data transmission in setup()
   ```cpp
   Serial.begin(115200);
   ```

3. Print LED state in timer_callback()
   ```cpp
   void timer_callback(rcl_timer_t* timer, int64_t last_call_time) {
     RCLC_UNUSED(last_call_time);
     if (timer != NULL) {

       int led_state = digitalRead(RGB_BUILTIN);
       const char* s = (led_state == HIGH) ? "on" : "off";
       strcpy(status_msg.data.data, s);
       status_msg.data.size = strlen(s);

       RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

       Serial.print("timer: LED is ");
       Serial.println(s);
     }
   }
   ```

4. Upload the code

5. Run microROS agent and ROS2 node:
   Terminal #1:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   > 📢 Remember to reset the board
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```

6. Open the serial monitor from Arduino IDE and set the baud rate to 115200
   > 🔍 What is being printing?

<details>
<summary>Solution</summary>

```c
#include <micro_ros_arduino.h>

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/string.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rcl_publisher_t publisher;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

std_msgs__msg__String status_msg;
char status_msg_buf[4];

#define LED_PIN RGB_BUILTIN

#define RCCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) { error_loop(); } \
  }
#define RCSOFTCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) {} \
  }


void error_loop() {
  while (1) {
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);
    delay(100);
  }
}

void subscription_callback(const void *msgin) {
  const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;

  int cmd = msg->data;

  if (cmd == 0) {
    digitalWrite(LED_PIN, LOW);
  } else if (cmd == 1) {
    digitalWrite(LED_PIN, HIGH);
  }
}

void timer_callback(rcl_timer_t *timer, int64_t last_call_time) {
  RCLC_UNUSED(last_call_time);
  if (timer != NULL) {
    
    int led_state = digitalRead(RGB_BUILTIN);
    const char* s = (led_state == HIGH) ? "on" : "off";
    strcpy(status_msg.data.data, s);
    status_msg.data.size = strlen(s);  

    RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

    Serial.print("timer: LED is ");
    Serial.println(s);

  }
}

void setup() {

  Serial.begin(115200);

  set_microros_transports();

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  delay(2000);

  allocator = rcl_get_default_allocator();

  //create init_options
  RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));

  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));
  
  // initiatialise internal string buffer
  std_msgs__msg__String__init(&status_msg);
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer,
  const unsigned int timer_timeout = 1000;
  RCCHECK(rclc_timer_init_default(
    &timer,
    &support,
    RCL_MS_TO_NS(timer_timeout),
    timer_callback));


  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 2, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
  RCCHECK(rclc_executor_add_timer(&executor, &timer));

}

void loop() {
  delay(100);
  RCCHECK(rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100)));
}
```

</details>

## Exercise 5: Debugging - Serial Output 2

```cpp
void setup() {
	Serial.begin(115200);
  Serial1.begin(115200, SERIAL_8N1, 7, 32);
}
```

Usage:

```cpp
Serial1.print("LED status ")
```

<details>
<summary>Solution</summary>

```c
#include <micro_ros_arduino.h>

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/string.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rcl_publisher_t publisher;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

std_msgs__msg__String status_msg;
char status_msg_buf[4];

#define LED_PIN RGB_BUILTIN

#define RCCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) { error_loop(); } \
  }
#define RCSOFTCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) {} \
  }


void error_loop() {
  while (1) {
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);
    delay(100);
  }
}

void subscription_callback(const void *msgin) {
  const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;

  int cmd = msg->data;

  if (cmd == 0) {
    digitalWrite(LED_PIN, LOW);
  } else if (cmd == 1) {
    digitalWrite(LED_PIN, HIGH);
  }
}

void timer_callback(rcl_timer_t *timer, int64_t last_call_time) {
  RCLC_UNUSED(last_call_time);
  if (timer != NULL) {
    
    int led_state = digitalRead(RGB_BUILTIN);
    const char* s = (led_state == HIGH) ? "on" : "off";
    strcpy(status_msg.data.data, s);
    status_msg.data.size = strlen(s);  

    RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

    Serial1.print("timer: LED is ");
    Serial1.println(s);
  }
}

void setup() {

  Serial.begin(115200);
  Serial1.begin(115200, SERIAL_8N1, 7, 32);

  set_microros_transports();

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  delay(2000);

  allocator = rcl_get_default_allocator();

  //create init_options
  RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));

  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));
  
  // initiatialise internal string buffer
  std_msgs__msg__String__init(&status_msg);
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer,
  const unsigned int timer_timeout = 1000;
  RCCHECK(rclc_timer_init_default(
    &timer,
    &support,
    RCL_MS_TO_NS(timer_timeout),
    timer_callback));


  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 2, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
  RCCHECK(rclc_executor_add_timer(&executor, &timer));

}

void loop() {
  delay(100);
  RCCHECK(rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100)));
}
```

</details>

## Exercise 6: Debugging - ROS Logs

1. Open file exercise3 and save the file as exercise6

2. Include logging library
   ```cpp
   #include <rcl_interfaces/msg/log.h>
   ```

3. Declare log publisher, message type and message buffer
   ```cpp
   rcl_publisher_t publisher_log;
   rcl_interfaces__msg__Log msgLog;
   char log_name_buf[16] = "ESP32";
   char log_msg_buf[64];
   ```

4. Create log helper function
   ```cpp
   void publish_log(uint8_t level, const char* text) {
     msgLog.level = level;
     strncpy(msgLog.msg.data, text, msgLog.msg.capacity - 1);
     msgLog.msg.data[msgLog.msg.capacity - 1] = '\0';
     msgLog.msg.size = strlen(msgLog.msg.data);
     RCSOFTCHECK(rcl_publish(&publisher_log, &msgLog, NULL));
   }
   ```

5. Log LED status in timer_callback()
   ```cpp
   void timer_callback(rcl_timer_t* timer, int64_t last_call_time) {
     RCLC_UNUSED(last_call_time);
     if (timer != NULL) {

       int led_state = digitalRead(RGB_BUILTIN);
       const char* s = (led_state == HIGH) ? "on" : "off";
       strcpy(status_msg.data.data, s);
       status_msg.data.size = strlen(s);

       RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

       char log_text[32];
       snprintf(log_text, sizeof(log_text), "LED status: %s", s);
       publish_log(rcl_interfaces__msg__Log__INFO, log_text);
     }
   }
   ```

6. Initialise log message buffers in setup()
   ```c
   // initialize log message buffers
   rcl_interfaces__msg__Log__init(&msgLog);
   msgLog.name.data = log_name_buf;
   msgLog.name.size = strlen(log_name_buf);
   msgLog.name.capacity = sizeof(log_name_buf);
   msgLog.msg.data = log_msg_buf;
   msgLog.msg.size = 0;
   msgLog.msg.capacity = sizeof(log_msg_buf);
   ```

7. Create a publisher
   ```c
   // create publisher for logging
   RCCHECK(rclc_publisher_init_default(
     &publisher_log,
     &node,
     ROSIDL_GET_MSG_TYPE_SUPPORT(rcl_interfaces, msg, Log),
     "rosout"));
   ```

8. Upload the code

9. Run microROS agent and ROS2 node:
   Terminal #1:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```
   Terminal #3:
   ```bash
   # Log level: 10(DEBUG), 20(INFO), and 30(WARN)
   ros2 topic echo /hyc/rosout
   ```

> 🤔 What if connection fails, there’s no way to debug as ROS2 is unable to read /rosout topic

<details>
<summary>Solution</summary>

```c
#include <micro_ros_arduino.h>
#include <rcl_interfaces/msg/log.h>

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/string.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rcl_publisher_t publisher;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

std_msgs__msg__String status_msg;
char status_msg_buf[4];

rcl_publisher_t publisher_log;
rcl_interfaces__msg__Log msgLog;
char log_name_buf[16] = "ESP32";
char log_msg_buf[64];

#define LED_PIN RGB_BUILTIN

#define RCCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) { error_loop(); } \
  }
#define RCSOFTCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) {} \
  }


void error_loop() {
  while (1) {
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);
    delay(100);
  }
}

void subscription_callback(const void *msgin) {
  const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;

  int cmd = msg->data;

  if (cmd == 0) {
    digitalWrite(LED_PIN, LOW);
  } else if (cmd == 1) {
    digitalWrite(LED_PIN, HIGH);
  }
}

void timer_callback(rcl_timer_t *timer, int64_t last_call_time) {
  RCLC_UNUSED(last_call_time);
  if (timer != NULL) {
    
    int led_state = digitalRead(RGB_BUILTIN);
    const char* s = (led_state == HIGH) ? "on" : "off";
    strcpy(status_msg.data.data, s);
    status_msg.data.size = strlen(s);  

    RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

    char log_text[32];
    snprintf(log_text, sizeof(log_text), "LED status: %s", s);
    publish_log(rcl_interfaces__msg__Log__INFO, log_text);

  }
}

void publish_log(uint8_t level, const char* text) {
  msgLog.level = level;
  strncpy(msgLog.msg.data, text, msgLog.msg.capacity - 1);
  msgLog.msg.data[msgLog.msg.capacity - 1] = '\0';
  msgLog.msg.size = strlen(msgLog.msg.data);
  RCSOFTCHECK(rcl_publish(&publisher_log, &msgLog, NULL));
}

void setup() {
  set_microros_transports();

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  delay(2000);

  allocator = rcl_get_default_allocator();

  //create init_options
  RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));

  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));
  
  // initiatialise string buffer
  std_msgs__msg__String__init(&status_msg);
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // initialize log message buffers
  rcl_interfaces__msg__Log__init(&msgLog);
  msgLog.name.data = log_name_buf;
  msgLog.name.size = strlen(log_name_buf);
  msgLog.name.capacity = sizeof(log_name_buf);
  msgLog.msg.data = log_msg_buf;
  msgLog.msg.size = 0;
  msgLog.msg.capacity = sizeof(log_msg_buf);

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));
  
  // create publisher for logging
  RCCHECK(rclc_publisher_init_default(
    &publisher_log,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(rcl_interfaces, msg, Log),
    "rosout"));

  // create timer,
  const unsigned int timer_timeout = 1000;
  RCCHECK(rclc_timer_init_default(
    &timer,
    &support,
    RCL_MS_TO_NS(timer_timeout),
    timer_callback));


  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 2, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
  RCCHECK(rclc_executor_add_timer(&executor, &timer));

}

void loop() {
  delay(100);
  RCCHECK(rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100)));
}
```

</details>

Log error message

```cpp
void error_loop() {

  publish_log(rcl_interfaces__msg__Log__ERROR, "Enter error loop!");

  while (1) {
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);  // Red
    delay(100);
  }
}
```

> ❓ How autoconnection is achieved???

## Exercise 7: ROS_DOMAIN_ID

1. Save the file as exercise7

2. Set ROS_DOMAIN_ID
   - For non-docker user:
     ```bash
     # Set ROS_DOMAIN_ID
     echo 'export ROS_DOMAIN_ID=17' >> ~/.bashrc
     ```
     > ⚠️ Close all the terminals and restart again
   - Docker user:
     ```bash
     ./run.sh /dev/ttyACM0 17   # domain 17
     ```
   Verify the domain ID is correctly set in new terminal or container
   ```bash
   echo $ROS_DOMAIN_ID
   ```

3. Replace RCCHECK(rclc_support_init(&support, 0, NULL, &allocator)); with:
   ```c
   rcl_init_options_t init_options = rcl_get_zero_initialized_init_options();
   RCCHECK(rcl_init_options_init(&init_options, allocator));
   RCCHECK(rcl_init_options_set_domain_id(&init_options, 17));
   RCCHECK(rclc_support_init_with_options(&support, 0, NULL, &init_options, &allocator));
   ```

4. Upload the code

5. Run microROS agent and ROS2 node:
   Terminal #1:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```
   Terminal #3:
   ```bash
   ros2 node list
   ros2 topic list
   ```

<details>
<summary>Solution</summary>

```c
#include <micro_ros_arduino.h>
#include <rcl_interfaces/msg/log.h>

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/string.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rcl_publisher_t publisher;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

std_msgs__msg__String status_msg;
char status_msg_buf[4];

rcl_publisher_t publisher_log;
rcl_interfaces__msg__Log msgLog;
char log_name_buf[16] = "ESP32";
char log_msg_buf[64];

#define LED_PIN RGB_BUILTIN

#define RCCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) { error_loop(); } \
  }
#define RCSOFTCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) {} \
  }


void error_loop() {
  while (1) {
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);
    delay(100);
  }
}

void subscription_callback(const void *msgin) {
  const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;

  int cmd = msg->data;

  if (cmd == 0) {
    digitalWrite(LED_PIN, LOW);
  } else if (cmd == 1) {
    digitalWrite(LED_PIN, HIGH);
  }
}

void timer_callback(rcl_timer_t *timer, int64_t last_call_time) {
  RCLC_UNUSED(last_call_time);
  if (timer != NULL) {
    
    int led_state = digitalRead(RGB_BUILTIN);
    const char* s = (led_state == HIGH) ? "on" : "off";
    strcpy(status_msg.data.data, s);
    status_msg.data.size = strlen(s);  

    RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

    char log_text[32];
    snprintf(log_text, sizeof(log_text), "LED status: %s", s);
    publish_log(rcl_interfaces__msg__Log__INFO, log_text);

  }
}

void publish_log(uint8_t level, const char* text) {
  msgLog.level = level;
  strncpy(msgLog.msg.data, text, msgLog.msg.capacity - 1);
  msgLog.msg.data[msgLog.msg.capacity - 1] = '\0';
  msgLog.msg.size = strlen(msgLog.msg.data);
  RCSOFTCHECK(rcl_publish(&publisher_log, &msgLog, NULL));
}

void setup() {
  set_microros_transports();

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  delay(2000);

  allocator = rcl_get_default_allocator();

  //create init_options
  rcl_init_options_t init_options = rcl_get_zero_initialized_init_options();
  RCCHECK(rcl_init_options_init(&init_options, allocator));
  RCCHECK(rcl_init_options_set_domain_id(&init_options, 17));
  RCCHECK(rclc_support_init_with_options(&support, 0, NULL, &init_options, &allocator));

  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));
  
  // initiatialise string buffer
  std_msgs__msg__String__init(&status_msg);
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // initialize log message buffers
  rcl_interfaces__msg__Log__init(&msgLog);
  msgLog.name.data = log_name_buf;
  msgLog.name.size = strlen(log_name_buf);
  msgLog.name.capacity = sizeof(log_name_buf);
  msgLog.msg.data = log_msg_buf;
  msgLog.msg.size = 0;
  msgLog.msg.capacity = sizeof(log_msg_buf);

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));
  
  // create publisher for logging
  RCCHECK(rclc_publisher_init_default(
    &publisher_log,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(rcl_interfaces, msg, Log),
    "rosout"));

  // create timer,
  const unsigned int timer_timeout = 1000;
  RCCHECK(rclc_timer_init_default(
    &timer,
    &support,
    RCL_MS_TO_NS(timer_timeout),
    timer_callback));


  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 2, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
  RCCHECK(rclc_executor_add_timer(&executor, &timer));

}

void loop() {
  delay(100);
  RCCHECK(rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100)));
}
```

</details>

## Exercise 8: Wi-Fi Transport

1. Configure hotspot
   1. Linux:
      - Option a: GUI
        Open **Settings > Wi-Fi > Click the three-dot icon > Turn on WiFi Hotspot**
      - Option b: Network manager command line
        ```bash
        nmcli device wifi hotspot ifname wlo1 ssid microros_esp32 password microros_esp32
        ```
   2. Windows:
      **Setting > Network & Internet > ‘Mobile Hotspot’**
      Toggle on ‘Mobile Hotspot’
      Edit network property: remove any space and special character and set the network band to 2.4 GHz

2. Get host IP from the terminal
   ```bash
   hostname -I

   # Windows (look for 'Wireless LAN adapter Local Area Connection')
   ipconfig
   ```

3. Open file exercise4 and save the file as exercise8

4. Create a new tab by clicking on the 3 horizontal dots at top/right of the window and name secrets.h to define credentials
   ```cpp
   char* ssid = "microros_esp32";
   char* password = "microros_esp32";
   char* agent_ip = "10.42.0.1";
   uint32_t agent_port = 8888;  // Default micro-ROS agent port
   ```
   > 🔐 **Good Practice: Keep Credentials Separate**
   >
   > Store Wi-Fi credentials, API keys, passwords, and other sensitive information in a separate file instead of hardcoding them in main source files.
   >
   > **Remember:** Add the credentials file to `.gitignore` so it is never committed to Git. If others need to use the project, provide a template file (e.g., `secrets_example.h`) with placeholder values and instructions for creating their own local credentials file.

5. Update firmware and transport
   1. Include credientials
      ```cpp
      #include "secrets.h"
      ```
   2. Replace set_microros_transports() in setup() with
      ```cpp
      set_microros_wifi_transports(ssid, password, agent_ip, agent_port);
      ```

6. Set domain ID (the same as previous exercise)
   Replace RCCHECK(rclc_support_init(&support, 0, NULL, &allocator)); with:
   ```c
   rcl_init_options_t init_options = rcl_get_zero_initialized_init_options();
   RCCHECK(rcl_init_options_init(&init_options, allocator));
   RCCHECK(rcl_init_options_set_domain_id(&init_options, 17));
   RCCHECK(rclc_support_init_with_options(&support, 0, NULL, &init_options, &allocator));
   ```

7. Upload the code

8. Run microROS agent and ROS2 node
   Terminal #1:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent udp4 --port 8888
   ```
   Terminal #2
   ```bash
   ros2 run led_demo led_control
   ```

9. Open the serial monitor from Arduino IDE and set the baud rate to 115200

<details>
<summary>Solution</summary>

```c
#include <micro_ros_arduino.h>
#include "secrets.h"

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/string.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rcl_publisher_t publisher;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

std_msgs__msg__String status_msg;
char status_msg_buf[4];

#define LED_PIN RGB_BUILTIN

#define RCCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) { error_loop(); } \
  }
#define RCSOFTCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) {} \
  }


void error_loop() {
  while (1) {
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);
    delay(100);
  }
}

void subscription_callback(const void *msgin) {
  const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;

  int cmd = msg->data;

  if (cmd == 0) {
    digitalWrite(LED_PIN, LOW);
  } else if (cmd == 1) {
    digitalWrite(LED_PIN, HIGH);
  }
}

void timer_callback(rcl_timer_t *timer, int64_t last_call_time) {
  RCLC_UNUSED(last_call_time);
  if (timer != NULL) {
    
    int led_state = digitalRead(RGB_BUILTIN);
    const char* s = (led_state == HIGH) ? "on" : "off";
    strcpy(status_msg.data.data, s);
    status_msg.data.size = strlen(s);  

    RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

    Serial.print("timer: LED is ");
    Serial.println(s);

  }
}

void setup() {

  Serial.begin(115200);

  set_microros_wifi_transports(ssid, password, agent_ip, agent_port);

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  delay(2000);

  allocator = rcl_get_default_allocator();

  //create init_options
  rcl_init_options_t init_options = rcl_get_zero_initialized_init_options();
  RCCHECK(rcl_init_options_init(&init_options, allocator));
  RCCHECK(rcl_init_options_set_domain_id(&init_options, 17));
  RCCHECK(rclc_support_init_with_options(&support, 0, NULL, &init_options, &allocator));

  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));
  
  // initiatialise internal string buffer
  std_msgs__msg__String__init(&status_msg);
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer,
  const unsigned int timer_timeout = 1000;
  RCCHECK(rclc_timer_init_default(
    &timer,
    &support,
    RCL_MS_TO_NS(timer_timeout),
    timer_callback));

  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 2, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
  RCCHECK(rclc_executor_add_timer(&executor, &timer));

}

void loop() {
  delay(100);
  RCCHECK(rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100)));
}
```

</details>

## Exercise 9: Wi-Fi Stability & Debugging

1. Save as exercise9

2. Add helper functions
   ```cpp
   bool connectWiFi(unsigned long timeout_ms = 15000) {
     Serial.print("[WIFI] Connecting to SSID: ");
     Serial.println(ssid);
     WiFi.begin(ssid, password);
     unsigned long start = millis();
     while (WiFi.status() != WL_CONNECTED) {
       if (millis() - start > timeout_ms) {
         Serial.println("\n[WIFI] Connect timeout");
         return false;
       }
       Serial.print("[");
       Serial.print(WiFi.status());
       Serial.print("]");
       delay(500);
     }
     Serial.println("\n[WIFI] Connected. IP: " + WiFi.localIP().toString());
     return true;
   }

   void pingAgent(unsigned long ping_interval_ms = 1000) {
     Serial.print("[MICROROS] Pinging agent at ");
     Serial.print(agent_ip);
     Serial.print(":");
     Serial.print(agent_port);
     Serial.print(" ");
     while (rmw_uros_ping_agent(ping_interval_ms, 1) != RMW_RET_OK) {
       Serial.print(".");
       delay(200);
     }
     Serial.println("\n[MICROROS] Agent found!");
   }
   ```
   | **WiFi.status()** | **Meaning** |
   | --- | --- |
   | `0` (IDLE) | Connection attempt in progress. If stuck here, the Wi-Fi hardware isn't initializing properly or the connection attempt hasn't completed yet. |
   | `1`(NO_SSID_AVAIL) | ESP32 can't see the network at all. Points to an SSID mismatch or the hotspot not actually broadcasting on 2.4GHz (ESP32 doesn't support 5GHz). |
   | `4` (CONNECT_FAILED) | Network found, but authentication or password is incorrect. |
   | `6` (DISCONNECTED) | Was connected but got dropped. Could mean the hotspot was turned off or the ESP32 moved out of range. |

3. Improve setup reliability
   ```cpp
     if (!connectWiFi()) {
       Serial.println("[SETUP] WiFi failed. Halting.");
       while (true)
         delay(1000);
     }

     set_microros_wifi_transports(ssid, password, agent_ip, agent_port);
     pingAgent();
   ```

4. Upload the code
   > 🗣 Since the micro-ROS agent now connects over Wi-Fi, there's no need to stop and restart the agent when uploading code.

5. Run microROS agent and ROS2 node
   Terminal #1:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent udp4 --port 8888
   ```
   Terminal #2
   ```bash
   ros2 run led_demo led_control
   ```

<details>
<summary>Solution</summary>

```c
#include <micro_ros_arduino.h>
#include "secrets.h"

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/string.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rcl_publisher_t publisher;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

std_msgs__msg__String status_msg;
char status_msg_buf[4];

#define LED_PIN RGB_BUILTIN

#define RCCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) { error_loop(); } \
  }
#define RCSOFTCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) {} \
  }


void error_loop() {
  while (1) {
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);
    delay(100);
  }
}

void subscription_callback(const void *msgin) {
  const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;

  int cmd = msg->data;

  if (cmd == 0) {
    digitalWrite(LED_PIN, LOW);
  } else if (cmd == 1) {
    digitalWrite(LED_PIN, HIGH);
  }
}

void timer_callback(rcl_timer_t *timer, int64_t last_call_time) {
  RCLC_UNUSED(last_call_time);
  if (timer != NULL) {
    
    int led_state = digitalRead(RGB_BUILTIN);
    const char* s = (led_state == HIGH) ? "on" : "off";
    strcpy(status_msg.data.data, s);
    status_msg.data.size = strlen(s);  

    RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

    Serial.print("timer: LED is ");
    Serial.println(s);

  }
}

bool connectWiFi(unsigned long timeout_ms = 15000) {
  Serial.print("[WIFI] Connecting to SSID: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start > timeout_ms) {
      Serial.println("\n[WIFI] Connect timeout");
      return false;
    }
    Serial.print("[");
    Serial.print(WiFi.status());
    Serial.print("]");
    delay(500);
  }
  Serial.println("\n[WIFI] Connected. IP: " + WiFi.localIP().toString());
  return true;
}

void pingAgent(unsigned long ping_interval_ms = 1000) {
  Serial.print("[MICROROS] Pinging agent at ");
  Serial.print(agent_ip);
  Serial.print(":");
  Serial.print(agent_port);
  Serial.print(" ");
  while (rmw_uros_ping_agent(ping_interval_ms, 1) != RMW_RET_OK) {
    Serial.print(".");
    delay(200);
  }
  Serial.println("\n[MICROROS] Agent found!");
}

void setup() {

  Serial.begin(115200);

  if (!connectWiFi()) {
    Serial.println("[SETUP] WiFi failed. Halting.");
    while (true)
      delay(1000);
  }

  set_microros_wifi_transports(ssid, password, agent_ip, agent_port);
  pingAgent();

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  delay(2000);

  allocator = rcl_get_default_allocator();

  //create init_options
  rcl_init_options_t init_options = rcl_get_zero_initialized_init_options();
  RCCHECK(rcl_init_options_init(&init_options, allocator));
  RCCHECK(rcl_init_options_set_domain_id(&init_options, 17));
  RCCHECK(rclc_support_init_with_options(&support, 0, NULL, &init_options, &allocator));

  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));
  
  // initiatialise internal string buffer
  std_msgs__msg__String__init(&status_msg);
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer,
  const unsigned int timer_timeout = 1000;
  RCCHECK(rclc_timer_init_default(
    &timer,
    &support,
    RCL_MS_TO_NS(timer_timeout),
    timer_callback));


  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 2, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
  RCCHECK(rclc_executor_add_timer(&executor, &timer));

}

void loop() {
  delay(100);
  RCCHECK(rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100)));
}
```

</details>

## Exercise 10: Reconnection Handling

What if we don’t have access to the reset button on the board or can’t power cycle the microcontroller?

1. Save as exercise10

2. Open the example file File > Examples > micro_ros_arduino > micro-ros_reconnection_example

3. Implement reconnection logic
   - Include microROS RMW library
     ```cpp
     #include <rmw_microros/rmw_microros.h>
     ```
   - Keep RCSOFTCHECK(fn) and replace original RCCHECK(fn) with new RCCHECK(fn) and EXECUTE_EVERY_N_MS
   - Add enum state
   - Create create_entities() and replace the content with those used to be in the setup. Remember to keep return true; in the end
   - Right after rclc_support_init_with_options() inside create_entities(), add the following line
     ```c
       // free init_options heap alloc now that support has copied what it needs
       // prevents a leak on every reconnect
       RCCHECK(rcl_init_options_fini(&init_options));
     ```
   - Create destroy_entities() and replace the content with those entities that have been created
     ```c
     void destroy_entities() {
       rmw_context_t *rmw_context = rcl_context_get_rmw_context(&support.context);
       (void)rmw_uros_set_context_entity_destroy_session_timeout(rmw_context, 0);

       rcl_publisher_fini(&publisher, &node);
       rcl_subscription_fini(&subscriber, &node);
       rcl_timer_fini(&timer);
       rclc_executor_fini(&executor);
       rcl_node_fini(&node);
       rclc_support_fini(&support);
     }
     ```
   - Create the initial state in setup()
     ```cpp
     state = WAITING_AGENT;
     ```
   - Copy the switch case function to the loop()

4. Run microROS agent and ROS2 node
   Terminal #1:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent udp4 --port 8888
   ```
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```

<details>
<summary>Solution</summary>

```c
#include <micro_ros_arduino.h>
#include "secrets.h"

#include <stdio.h>
#include <rcl/rcl.h>
#include <rcl/error_handling.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>
#include <rmw_microros/rmw_microros.h>


#include <std_msgs/msg/int32.h>
#include <std_msgs/msg/string.h>

rcl_subscription_t subscriber;
std_msgs__msg__Int32 msg;
rcl_publisher_t publisher;
rclc_executor_t executor;
rclc_support_t support;
rcl_allocator_t allocator;
rcl_node_t node;
rcl_timer_t timer;

std_msgs__msg__String status_msg;
char status_msg_buf[4];

#define LED_PIN RGB_BUILTIN
#define RCSOFTCHECK(fn) \
  { \
    rcl_ret_t temp_rc = fn; \
    if ((temp_rc != RCL_RET_OK)) {} \
  }
#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){return false;}}

#define EXECUTE_EVERY_N_MS(MS, X) \
  do { \
    static volatile int64_t init = -1; \
    if (init == -1) { init = uxr_millis(); } \
    if (uxr_millis() - init > MS) { \
      X; \
      init = uxr_millis(); \
    } \
  } while (0)

enum states {
  WAITING_AGENT,
  AGENT_AVAILABLE,
  AGENT_CONNECTED,
  AGENT_DISCONNECTED
} state;

void error_loop() {
  while (1) {
    rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);
    delay(100);
  }
}

void subscription_callback(const void *msgin) {
  const std_msgs__msg__Int32 *msg = (const std_msgs__msg__Int32 *)msgin;

  int cmd = msg->data;

  if (cmd == 0) {
    digitalWrite(LED_PIN, LOW);
  } else if (cmd == 1) {
    digitalWrite(LED_PIN, HIGH);
  }
}

void timer_callback(rcl_timer_t *timer, int64_t last_call_time) {
  RCLC_UNUSED(last_call_time);
  if (timer != NULL) {

    int led_state = digitalRead(RGB_BUILTIN);
    const char *s = (led_state == HIGH) ? "on" : "off";
    strcpy(status_msg.data.data, s);
    status_msg.data.size = strlen(s);

    RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));

    Serial.print("timer: LED is ");
    Serial.println(s);
  }
}

bool connectWiFi(unsigned long timeout_ms = 15000) {
  Serial.print("[WIFI] Connecting to SSID: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start > timeout_ms) {
      Serial.println("\n[WIFI] Connect timeout");
      return false;
    }
    Serial.print("[");
    Serial.print(WiFi.status());
    Serial.print("]");
    delay(500);
  }
  Serial.println("\n[WIFI] Connected. IP: " + WiFi.localIP().toString());
  return true;
}

void pingAgent(unsigned long ping_interval_ms = 1000) {
  Serial.print("[MICROROS] Pinging agent at ");
  Serial.print(agent_ip);
  Serial.print(":");
  Serial.print(agent_port);
  Serial.print(" ");
  while (rmw_uros_ping_agent(ping_interval_ms, 1) != RMW_RET_OK) {
    Serial.print(".");
    delay(200);
  }
  Serial.println("\n[MICROROS] Agent found!");
}

bool create_entities() {
  allocator = rcl_get_default_allocator();

  //create init_options
  rcl_init_options_t init_options = rcl_get_zero_initialized_init_options();
  RCCHECK(rcl_init_options_init(&init_options, allocator));
  RCCHECK(rcl_init_options_set_domain_id(&init_options, 17));
  RCCHECK(rclc_support_init_with_options(&support, 0, NULL, &init_options, &allocator));
  RCCHECK(rcl_init_options_fini(&init_options));
  
  // create node
  RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));

  // create subscriber
  RCCHECK(rclc_subscription_init_default(
    &subscriber,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
    "led_control"));

  // initiatialise internal string buffer
  std_msgs__msg__String__init(&status_msg);
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer,
  const unsigned int timer_timeout = 1000;
  RCCHECK(rclc_timer_init_default(
    &timer,
    &support,
    RCL_MS_TO_NS(timer_timeout),
    timer_callback));


  // create executor
  RCCHECK(rclc_executor_init(&executor, &support.context, 2, &allocator));
  RCCHECK(rclc_executor_add_subscription(&executor, &subscriber, &msg, &subscription_callback, ON_NEW_DATA));
  RCCHECK(rclc_executor_add_timer(&executor, &timer));


  return true;
}

void destroy_entities() {
  rmw_context_t *rmw_context = rcl_context_get_rmw_context(&support.context);
  (void)rmw_uros_set_context_entity_destroy_session_timeout(rmw_context, 0);

  rcl_publisher_fini(&publisher, &node);
  rcl_subscription_fini(&subscriber, &node);
  rcl_timer_fini(&timer);
  rclc_executor_fini(&executor);
  rcl_node_fini(&node);
  rclc_support_fini(&support);
}

void setup() {

  Serial.begin(115200);

  if (!connectWiFi()) {
    Serial.println("[SETUP] WiFi failed. Halting.");
    while (true)
      delay(1000);
  }

  set_microros_wifi_transports(ssid, password, agent_ip, agent_port);
  pingAgent();

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, HIGH);

  state = WAITING_AGENT;


  delay(2000);
}

void loop() {
  Serial.println(state);
  switch (state) {
    case WAITING_AGENT:
      EXECUTE_EVERY_N_MS(500, state = (RMW_RET_OK == rmw_uros_ping_agent(100, 1)) ? AGENT_AVAILABLE : WAITING_AGENT;);
      break;
    case AGENT_AVAILABLE:
      state = (true == create_entities()) ? AGENT_CONNECTED : WAITING_AGENT;
      if (state == WAITING_AGENT) {
        destroy_entities();
      };
      break;
    case AGENT_CONNECTED:
      EXECUTE_EVERY_N_MS(200, state = (RMW_RET_OK == rmw_uros_ping_agent(100, 1)) ? AGENT_CONNECTED : AGENT_DISCONNECTED;);
      if (state == AGENT_CONNECTED) {
        rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100));
      }
      break;
    case AGENT_DISCONNECTED:
      destroy_entities();
      state = WAITING_AGENT;
      break;
    default:
      break;
  }
}
```

</details>
