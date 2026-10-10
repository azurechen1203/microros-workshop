# micro-ROS Workshop Handout

> Make sure you've completed the setup in [README.md](README.md) first: Docker, Arduino IDE with ESP32 board support and the micro-ROS library, the repo clone, the workshop image, and the micro-ROS agent should all be ready before you start here.

## Getting Started

1. Find the ESP32's serial port  
      Plug in the board, then run the following command on your own machine:
   ```bash
   ls /dev/ttyACM* /dev/ttyUSB*
   ```
   You should see something like `/dev/ttyACM0`. If nothing is listed, try another USB cable, as some are charge only.

   > 📢 This handout uses `/dev/ttyACM0` throughout. If yours is different, replace it in every `--dev` command, e.g. `--dev /dev/ttyUSB0`.

2. Start the container (Terminal #1)
   ```bash
   cd ~/microros_workshop/workshop
   ./run.sh
   ```
   Your prompt changes to `rosuser@<container id>`, which means you're now inside the container.

3. Open more terminals (Terminal #2, #3, ...)
   ```bash
   cd ~/microros_workshop/workshop
   ./attach.sh
   ```
   Each one opens another shell in the same running container.

4. Leave the container, when needed
   ```bash
   exit
   ```
   or press `Ctrl+D`

### Good to Know

- `run.sh` mounts `ros2_ws/` and `microros_ws/` from your machine, so your work is kept when the container stops.
- Closing Terminal #1 or running `./run.sh` again ends the current container and closes every attached terminal. Don't panic: just run `./run.sh` again and reattach.

## First micro-ROS Client Test

1. Open an example file  
   Go to: **File > Examples > micro_ros_arduino > micro-ros_subscriber**

2. Replace LED pin with `RGB_BUILTIN`
   ```cpp
   #define LED_PIN RGB_BUILTIN
   ```

3. Add the namespace to the node by filling in the empty namespace `""`
   ```cpp
   RCCHECK(rclc_node_init_default(&node, "micro_ros_arduino_node", "hyc", &support));
   ```
   > 📢 `hyc` is just an example (author's initials). Replace it with your own namespace and keep it consistent across the commands below.

4. Select board and port
   - Board: Adafruit QT Py ESP32
   - Port: /dev/ttyACM0 (from Getting Started step 1)

5. Upload the code
   > 🤔 **Think:**
   >
   > 1. Observe the LED on the ESP32. What does it mean?
   >
   > 2. Run these in Terminal #1. Why don't the node and topic show up?
   >    ```bash
   >    ros2 node list
   >    ros2 topic list
   >    ```

   <details>
   <summary>Answers</summary>

   1. On for 2 seconds, then fast blinking: `rclc_support_init()` failed and the board entered `error_loop()`.
   2. The client can't join ROS 2 by itself. It needs the agent to bridge it to the ROS 2 network, and the agent isn't running yet.

   </details><br>

6. Source `microros_ws` and run the micro-ROS agent in Terminal #1
   ```bash
   source ~/microros_ws/install/local_setup.bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   > 🤔 **Think:**
   >
   > 1. Why does the LED still blink after starting the agent?
   >
   > 2. Why are the ROS 2 node and topic still missing?

   <details>
   <summary>Answers</summary>

   1. The board is stuck in `error_loop()`, which never retries. It needs a reset.
   2. The node and subscriber are created in `setup()`, which runs once at boot. No agent was running at boot, so no session was established and nothing was created on the ROS 2 side.

   </details><br>

7. Reset the board by pressing the `RESET` button  
   The agent prints lines such as `session established`, `topic created` and `subscriber created`.

8. Test communication  
   Terminal #2:
   ```bash
   ros2 node list
   # Expected output: /hyc/micro_ros_arduino_node

   ros2 topic list
   # Expected output includes: /hyc/micro_ros_arduino_subscriber

   ros2 topic echo /hyc/micro_ros_arduino_subscriber
   ```  

   Terminal #3:
   ```bash
   # publish 0 to turn LED off and 1 to turn back on
   ros2 topic pub --once /hyc/micro_ros_arduino_subscriber std_msgs/msg/Int32 "data: 0"
   ```

## File System Overview

Create the `firmware/` folder on your machine and save every Arduino sketch there.
```bash
mkdir -p ~/microros_workshop/workshop/firmware
```
By the end of the workshop, the folder will look like this:
```
~/microros_workshop/
├── README.md
├── HANDOUT.md
└── workshop/
    ├── Dockerfile
    ├── run.sh
    ├── attach.sh
    ├── firmware/                   # micro-ROS client (Arduino sketches)
    │   ├── exercise1/
    │   │   └── exercise1.ino
    │   └── exercise2/
    │       └── exercise2.ino
    ├── ros2_ws/                    # ROS 2 packages
    │   ├── src/
    │   │   └── led_demo/
    │   ├── build/
    │   ├── install/
    │   └── log/
    └── microros_ws/                # micro-ROS agent
```

## Exercise 1: LED Control (Subscriber)

1. Save the previous sketch as exercise1 in `firmware/`

2. Change the error loop LED colour to red to distinguish states
   ```cpp
   void error_loop(){
     while(1){
       rgbLedWrite(LED_PIN, RGB_BRIGHTNESS, 0, 0);  // Red
       delay(100);
     }
   }
   ```

3. Update the subscription callback so only 0 and 1 change the LED
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

4. Update the subscriber topic to `led_control`
   ```cpp
     RCCHECK(rclc_subscription_init_default(
       &subscriber,
       &node,
       ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, Int32),
       "led_control"));
   ```
   Keep it a relative name (no leading `/`), so the node namespace is added to it.

5. Upload the code
   > ⚠️ Remember to stop the micro-ROS agent in Terminal #1 with `Ctrl+C`, otherwise the Arduino IDE will show a "serial exception" error.
   
   The LED turns red: no agent is running, so the board is in `error_loop()`.

6. Run the micro-ROS agent and test it  
   Terminal #1, then press the `RESET` button:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   Terminal #2:
   ```bash
   # publish 0 to turn LED off and 1 to turn back on
   ros2 topic pub --once /hyc/led_control std_msgs/msg/Int32 "data: 0"
   ```

> 🤔 Stopping the agent and pressing reset after every upload gets tedious. Exercise 10 will have these covered.

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

## Create the ROS 2 Test Node

With the firmware confirmed working in Exercise 1, keep Terminal #1 for the micro-ROS agent. Build a small ROS 2 node in Terminal #2 so you don't need to type raw `ros2 topic pub`/`echo` commands for the rest of the workshop.

1. Create a ROS 2 package `led_demo`
   ```bash
   cd ~/ros2_ws/src
   ros2 pkg create led_demo --build-type ament_python
   ```

2. Create a script
   ```bash
   cd ~/ros2_ws/src/led_demo/led_demo
   nano led_control.py
   ```
   Paste the code below and replace `hyc` with your own namespace.
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
   - Publishes LED commands to `/led_control`
   - Subscribes to `/led_status`
   - Provides a simple CLI menu for interaction

3. Update `setup.py` to register the script as an executable
   ```bash
   cd ~/ros2_ws/src/led_demo
   nano setup.py
   ```
   In `entry_points`, add the `led_control` line so it looks like this:
   ```python
   entry_points={
       'console_scripts': [
           'led_control = led_demo.led_control:main'
       ],
   },
   ```

4. Build the workspace
   ```bash
   cd ~/ros2_ws
   colcon build
   source install/setup.bash
   ```

5. Run the ROS 2 node  
   Terminal #1, only if the agent was stopped (start it, then press `RESET`):
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```
   Enter `0` or `1` to switch the LED. Status shows `None` until Exercise 2 adds the publisher.

## Exercise 2: Monitor LED Status (Publisher)

1. Save exercise1 as exercise2 in `firmware/`

2. Open the example file for reference: **File > Examples > micro_ros_arduino > micro-ros_publisher**

3. Copy the publisher and timer parts. Here are some hints:
   - Declare `rcl_publisher_t publisher;` and `std_msgs__msg__Int32 status_msg;` (`timer` already exists)
   - Copy `timer_callback()` and remove `msg.data++`. Read the LED first, then publish `status_msg` instead of `msg`:
     ```cpp
     status_msg.data = (digitalRead(LED_PIN) == HIGH) ? 1 : 0;
     ```
   - In `setup()`, after the subscriber, create the publisher on `led_status`
   - After the publisher, create the timer
   - Change the number of executor handles from 1 to 2 in `rclc_executor_init`
   - Add the timer to the executor with `rclc_executor_add_timer()`

4. Upload the code
   > ⚠️ Remember to stop the micro-ROS agent in Terminal #1 with `Ctrl+C`, otherwise the Arduino IDE will show a "serial exception" error.

5. Run the micro-ROS agent and ROS 2 node  
   Terminal #1, then press the `RESET` button:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   Terminal #2, if `led_control` isn't still running:
   ```bash
   ros2 run led_demo led_control
   ```
   Terminal #3:
   ```bash
   ros2 topic echo /hyc/led_status
   ```
   The status updates every second. Switch the LED in Terminal #2 and watch it change.

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
    
  // create timer
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

1. Save exercise2 as exercise3 in `firmware/`

2. Change the publisher message `status_msg` from Int32 to String (the subscriber `msg` stays Int32)  
   Add library
   ```cpp
   #include <std_msgs/msg/string.h>
   ```
   Replace `std_msgs__msg__Int32 status_msg;` with a String message and a buffer
   ```cpp
   std_msgs__msg__String status_msg;
   char status_msg_buf[4];
   ```

3. Update `timer_callback()`
   ```cpp
   void timer_callback(rcl_timer_t * timer, int64_t last_call_time)
   {  
     RCLC_UNUSED(last_call_time);
     if (timer != NULL) {

       int led_state = digitalRead(LED_PIN);
       const char* s = (led_state == HIGH) ? "on" : "off";
       strcpy(status_msg.data.data, s);
       status_msg.data.size = strlen(s);  

       RCSOFTCHECK(rcl_publish(&publisher, &status_msg, NULL));
     }
   }
   ```

4. In `setup()`, set up the string buffer before the publisher and change the publisher type to String
   ```cpp
     // store the string in status_msg_buf
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
   > ⚠️ Remember to stop the micro-ROS agent in Terminal #1 with `Ctrl+C`, otherwise the Arduino IDE will show a "serial exception" error.

6. Update the ROS 2 node to subscribe to String  
   In Terminal #2:
   ```bash
   nano ~/ros2_ws/src/led_demo/led_demo/led_control.py
   ```
   Add `String` below the `Int32` import:
   ```python
   from std_msgs.msg import String
   ```
   Change the subscription and callback from `Int32` to `String`:
   ```python
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
   Terminal #2:
   ```bash
   cd ~/ros2_ws
   colcon build
   source install/setup.bash
   ```

8. Run the micro-ROS agent and ROS 2 node  
   Terminal #1, then press the `RESET` button:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```
   Terminal #3, stop the previous `ros2 topic echo` with `Ctrl+C` (it is still subscribed as Int32), then start it again:
   ```bash
   ros2 topic echo /hyc/led_status
   ```
   The status now shows `data: on` or `data: off`. Switch the LED in Terminal #2 and choose `2` to see the same text.

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

#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){error_loop();}}
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}


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
    
    int led_state = digitalRead(LED_PIN);
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
  
  // store the string in status_msg_buf
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer
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

1. Save exercise3 as exercise4 in `firmware/`

2. Initialise serial data transmission in `setup()`
   ```cpp
   Serial.begin(115200);
   ```

3. Print LED state in `timer_callback()`
   ```cpp
   void timer_callback(rcl_timer_t* timer, int64_t last_call_time) {
     RCLC_UNUSED(last_call_time);
     if (timer != NULL) {

       int led_state = digitalRead(LED_PIN);
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
   > ⚠️ Remember to stop the micro-ROS agent in Terminal #1 with `Ctrl+C`, otherwise the Arduino IDE will show a "serial exception" error.

5. Run the micro-ROS agent and ROS 2 node  
   Terminal #1, then press the `RESET` button:
   ```bash
   ros2 run micro_ros_agent micro_ros_agent serial --dev /dev/ttyACM0
   ```
   Terminal #2:
   ```bash
   ros2 run led_demo led_control
   ```

6. Open the serial monitor in the Arduino IDE and set the baud rate to 115200
   > 🤔 **Think:** What is printed? Does the LED still respond in Terminal #2?

   <details>
   <summary>Answers</summary>

   The monitor shows unreadable characters mixed with `timer: LED is on`, and the LED may respond late or not at all. This is because the micro-ROS agent and the serial monitor are both reading the same port. The monitor picks up micro-ROS messages, which are binary and show as `�`, and the agent misses them.

   </details><br>

7. Close the serial monitor

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

#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){error_loop();}}
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}


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
    
    int led_state = digitalRead(LED_PIN);
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
  
  // store the string in status_msg_buf
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer
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

If you have a USB-UART adapter, you can print debug messages on a second serial port while micro-ROS uses USB.

1. Connect adapter `RX` to board `TX`, and adapter `GND` to board `GND`

2. Initialise `Serial1` in `setup()` (RX on pin 7, TX on pin 32; only TX is used here)
   ```cpp
   Serial1.begin(115200, SERIAL_8N1, 7, 32);
   ```

3. Print with `Serial1` instead of `Serial`
   ```cpp
   Serial1.print("timer: LED is ");
   Serial1.println(s);
   ```

4. Select the adapter's port in the Arduino IDE, open the serial monitor and set the baud rate to 115200

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

#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){error_loop();}}
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}


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
    
    int led_state = digitalRead(LED_PIN);
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
  
  // store the string in status_msg_buf
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer
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

5. Log LED status in `timer_callback()`
   ```cpp
   void timer_callback(rcl_timer_t* timer, int64_t last_call_time) {
     RCLC_UNUSED(last_call_time);
     if (timer != NULL) {

       int led_state = digitalRead(LED_PIN);
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

6. Initialise log message buffers in `setup()`
   ```cpp
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
   ```cpp
   // create publisher for logging
   RCCHECK(rclc_publisher_init_default(
     &publisher_log,
     &node,
     ROSIDL_GET_MSG_TYPE_SUPPORT(rcl_interfaces, msg, Log),
     "rosout"));
   ```

8. Upload the code

9. Run micro-ROS agent and ROS2 node:  
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

```cpp
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

#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){error_loop();}}
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}


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
    
    int led_state = digitalRead(LED_PIN);
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
  
  // store the string in status_msg_buf
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

  // create timer
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

## Exercise 7: Domain ID Isolation

1. Save the file as exercise7

2. Set `ROS_DOMAIN_ID`
   ```bash
   ./run.sh 17   # domain 17
   ```
   > ℹ️ If you're not using this workshop's Docker container, set `ROS_DOMAIN_ID` via your own shell by `export ROS_DOMAIN_ID=17`.

   Verify the domain ID is correctly set in a new terminal or container
   ```bash
   echo $ROS_DOMAIN_ID
   ```

3. Replace `RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));` with:
   ```cpp
   rcl_init_options_t init_options = rcl_get_zero_initialized_init_options();
   RCCHECK(rcl_init_options_init(&init_options, allocator));
   RCCHECK(rcl_init_options_set_domain_id(&init_options, 17));
   RCCHECK(rclc_support_init_with_options(&support, 0, NULL, &init_options, &allocator));
   ```

4. Upload the code

5. Run micro-ROS agent and ROS2 node:  
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

```cpp
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

#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){error_loop();}}
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}


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
    
    int led_state = digitalRead(LED_PIN);
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
  
  // store the string in status_msg_buf
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

  // create timer
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
   - Option a: GUI
     Open **Settings > Wi-Fi > Click the three-dot icon > Turn on WiFi Hotspot**
   - Option b: Network manager command line
     ```bash
     nmcli device wifi hotspot ifname wlo1 ssid microros_esp32 password microros_esp32
     ```

2. Get host IP from the terminal
   ```bash
   hostname -I
   ```

3. Open file exercise4 and save the file as exercise8

4. Create a new tab by clicking on the 3 horizontal dots at top/right of the window and name `secrets.h` to define credentials
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
   > **Remember:** Add the credentials file to `.gitignore` so it is never committed to Git. If others need to use the project, provide a template file (e.g. `secrets_example.h`) with placeholder values and instructions for creating their own local credentials file.

5. Update firmware and transport
   - **A.** Include credientials
     ```cpp
     #include "secrets.h"
     ```
   - **B.** Replace `set_microros_transports()` in `setup()` with
     ```cpp
     set_microros_wifi_transports(ssid, password, agent_ip, agent_port);
     ```

6. Set domain ID (the same as previous exercise)
   Replace `RCCHECK(rclc_support_init(&support, 0, NULL, &allocator));` with:
   ```cpp
   rcl_init_options_t init_options = rcl_get_zero_initialized_init_options();
   RCCHECK(rcl_init_options_init(&init_options, allocator));
   RCCHECK(rcl_init_options_set_domain_id(&init_options, 17));
   RCCHECK(rclc_support_init_with_options(&support, 0, NULL, &init_options, &allocator));
   ```

7. Upload the code

8. Run micro-ROS agent and ROS2 node  
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

```cpp
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

#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){error_loop();}}
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}


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
    
    int led_state = digitalRead(LED_PIN);
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
  
  // store the string in status_msg_buf
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer
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
   | **`WiFi.status()`** | **Meaning** |
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

5. Run micro-ROS agent and ROS2 node  
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

```cpp
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

#define RCCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){error_loop();}}
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}


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
    
    int led_state = digitalRead(LED_PIN);
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
  
  // store the string in status_msg_buf
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer
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

2. Open the example file: **File > Examples > micro_ros_arduino > micro-ros_reconnection_example**

3. Implement reconnection logic
   - Include micro-ROS RMW library
     ```cpp
     #include <rmw_microros/rmw_microros.h>
     ```
   - Keep `RCSOFTCHECK(fn)` and replace original `RCCHECK(fn)` with new `RCCHECK(fn)` and `EXECUTE_EVERY_N_MS`
   - Add enum state
   - Create `create_entities()` and replace the content with those used to be in the setup. Remember to keep `return true;` in the end
   - Right after `rclc_support_init_with_options()` inside `create_entities()`, add the following line
     ```cpp
       // free init_options heap alloc now that support has copied what it needs
       // prevents a leak on every reconnect
       RCCHECK(rcl_init_options_fini(&init_options));
     ```
   - Create `destroy_entities()` and replace the content with those entities that have been created
     ```cpp
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
   - Create the initial state in `setup()`
     ```cpp
     state = WAITING_AGENT;
     ```
   - Copy the switch case function to the `loop()`

4. Run micro-ROS agent and ROS2 node  
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

```cpp
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
#define RCSOFTCHECK(fn) { rcl_ret_t temp_rc = fn; if((temp_rc != RCL_RET_OK)){}}
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

    int led_state = digitalRead(LED_PIN);
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

  // store the string in status_msg_buf
  status_msg.data.data = status_msg_buf;
  status_msg.data.capacity = sizeof(status_msg_buf);
  status_msg.data.size = 0;

  // create publisher
  RCCHECK(rclc_publisher_init_default(
    &publisher,
    &node,
    ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
    "led_status"));

  // create timer
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
