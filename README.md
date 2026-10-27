# ROS 2 Jazzy로 따라가는 "Programming Robots with ROS" 실습 가이드

Quigley, Gerkey, Smart의 *Programming Robots with ROS* (O'Reilly, 2015)는 ROS 1 Indigo를 기준으로 쓰인 책입니다. 이 가이드는 그 책을 옆에 펴 두고, 장마다 같은 목표를 ROS 2 Jazzy와 시뮬레이션으로 직접 실습하기 위한 한국어 학습 자료입니다.

가장 중요한 목표는 ROS 2의 구조를 정확히 이해하고 직접 체감하는 것입니다. 로봇이 잘 움직이는지는 그다음 문제입니다.

## 먼저 알아 둘 점: 번역본이 아닙니다

원서는 저작권이 있는 출판물이라서, 본문을 한국어로 옮겨 적은 번역본은 만들 수 없습니다. 그 대신 각 장마다 다음 내용을 새로 작성했습니다.

- 원서가 그 장에서 이루려는 목표와 핵심 개념을 짧게 다시 설명한 글
- 같은 목표를 ROS 2 Jazzy로 구현하는 실습 (명령, 전체 코드, 줄 단위 해설)
- 구조를 체감하기 위한 관찰 항목, 일부러 망가뜨려 보는 실험, 확인 질문

원서의 문장과 그림은 각 장 첫머리에 적어 둔 PDF 쪽 번호를 보고 원서에서 직접 읽으면 됩니다. 각 장이 어떤 순서로 구성되는지는 [CONVENTIONS.md](CONVENTIONS.md)에 정리되어 있습니다.

## 공부하는 방법

1. 원서의 해당 장을 먼저 훑어봅니다. 영어가 부담스러우면 이 가이드의 "목표와 개념"을 먼저 읽고 원서를 봐도 됩니다.
2. 실습의 명령과 코드는 복사하지 말고 직접 입력합니다. 오타 때문에 생긴 오류도 구조를 배우는 재료가 됩니다.
3. 실습마다 "관찰" 항목을 실제로 확인하고, "생각해 볼 질문"에 스스로 답해 봅니다. 답은 각 장의 "확인 질문"에 접혀 있습니다.
4. "일부러 망가뜨려 보기"는 건너뛰지 않습니다. 정상으로 동작할 때보다 망가졌을 때 ROS 2의 구조가 더 잘 드러납니다.
5. 막히면 장 번호와 실습 번호, 실행한 명령, 출력 전체를 Claude에게 보여 주고 질문합니다.

1~5장은 개념을 이미 읽었더라도 ROS 2 코드를 처음 직접 작성하는 단계이므로 순서대로 실습하기를 권합니다.

## 실습 환경

| 항목 | 내용 |
|---|---|
| OS | Windows 11 + WSL2 Ubuntu 24.04 |
| ROS | ROS 2 Jazzy (`/opt/ros/jazzy`) |
| 워크스페이스 | `~/rosbook_ws` (패키지는 `~/rosbook_ws/src/`) |
| 시뮬레이터 | Gazebo Harmonic (gz-sim 8) + `ros_gz_bridge` |
| 로봇 | TurtleBot3 waffle_pi 시뮬레이션 (LiDAR와 카메라 탑재). 실물 로봇은 쓰지 않습니다. |
| 통신 미들웨어 (RMW) | Cyclone DDS (`rmw_cyclonedds_cpp`). Jazzy의 기본값인 Fast DDS를 쓰지 않는 이유는 아래에 적었습니다. |
| 그래픽 | WSLg + `GALLIUM_DRIVER=d3d12` (Mesa가 D3D12를 거쳐 GPU로 렌더링) |

`~/.bashrc`는 새 터미널을 열 때마다 다음 설정을 불러옵니다. 그래서 터미널을 새로 열면 바로 `ros2` 명령을 쓸 수 있습니다.

- `/opt/ros/jazzy/setup.bash`와 `~/rosbook_ws/install/setup.bash`를 source 합니다.
- `TURTLEBOT3_MODEL=waffle_pi`
- `GALLIUM_DRIVER=d3d12`
- `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`

TurtleBot3 시뮬레이션은 다음 명령으로 띄웁니다.

```bash
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```

### 왜 Fast DDS 대신 Cyclone DDS를 쓰나요

ROS 2 노드는 메시지를 직접 주고받지 않고, RMW라는 계층 아래에 있는 DDS 구현에 전달을 맡깁니다. Jazzy는 기본으로 Fast DDS를 쓰고, 환경 변수 `RMW_IMPLEMENTATION`을 바꾸면 다른 DDS 구현으로 교체할 수 있습니다.

```
노드 코드 (rclpy, rclcpp)
   ↓
rcl (공통 C 라이브러리)
   ↓
rmw (미들웨어 인터페이스)
   ↓
DDS 구현: Fast DDS 또는 Cyclone DDS   ← RMW_IMPLEMENTATION이 고르는 부분
```

이 PC의 WSL은 `networkingMode=mirrored`로 설정되어 있습니다. 이 환경에서 Fast DDS로 `demo_nodes_cpp`의 talker와 listener를 띄웠더니, `ros2 topic list`에는 토픽이 보였지만 listener는 10초 동안 메시지를 한 건도 받지 못했습니다. 탐색 범위를 `LOCALHOST`나 `SUBNET`으로 바꿔도, UDP만 쓰도록 해도 결과가 같았습니다. 같은 시험을 Cyclone DDS로 하면 메시지가 정상적으로 도착했습니다. mirrored 네트워크 모드가 원인으로 보이지만, NAT 모드로 되돌려서 확인하지는 않았습니다.

RMW를 바꿔도 노드 코드, 토픽과 서비스 이름, QoS, launch 파일, `ros2` 명령은 모두 그대로입니다. 원서의 실습 내용도 영향을 받지 않습니다. 다만 다음 세 가지는 알아 두어야 합니다.

- 서로 통신하는 터미널은 모두 같은 RMW를 써야 합니다. `.bashrc`를 고치기 전에 열어 둔 터미널은 닫고 새로 엽니다.
- RMW를 바꾼 뒤에는 `ros2 daemon stop`을 한 번 실행합니다. 백그라운드에 떠 있던 daemon은 예전 RMW로 동작하고 있기 때문입니다.
- 인터넷 자료에 나오는 Fast DDS 전용 설정(XML 프로파일, Discovery Server, `FASTDDS_` 로 시작하는 환경 변수)은 이 환경에 적용되지 않습니다.

현재 쓰고 있는 RMW는 다음 명령으로 확인합니다. 2장에서 두 RMW를 직접 바꿔 가며 비교해 봅니다.

```bash
ros2 doctor --report | grep -i middleware
```

### 그래픽과 시뮬레이션 문제 해결

- `GALLIUM_DRIVER=d3d12`를 설정하면 Gazebo가 GPU로 렌더링합니다. 이 설정이 없으면 CPU로 렌더링하는 llvmpipe가 쓰이고, 시뮬레이션이 실제 시간보다 몇 배에서 수십 배 느리게 흘러갑니다. 지금 쓰는 렌더러는 `glxinfo -B | grep -i "renderer string"`으로 확인합니다.
- Gazebo 창이 뜨지 않거나 GUI가 비정상적으로 종료되면, 그 터미널에서만 CPU 렌더링으로 바꿔서 실행해 봅니다. 느리지만 안정적입니다.

  ```bash
  GALLIUM_DRIVER=llvmpipe ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
  ```
- `QT_QPA_PLATFORM=wayland`는 설정하지 않습니다. d3d12와 함께 쓰면 Gazebo GUI가 렌더링 창을 만들지 못합니다.
- 시뮬레이션을 Ctrl+C로 끌 때 Gazebo 서버가 `Segmentation fault`를 출력할 수 있습니다. 종료 과정에서만 생기는 현상이라 실습에는 영향이 없습니다.
- 시뮬레이션을 껐는데도 로봇 토픽이 계속 보이면, 이전 Gazebo 서버가 남아 있는지 `pgrep -af "gz sim"`으로 확인합니다.

## 목차

| 장 | 제목 | 문서 | 원서 PDF 쪽 |
|---|---|---|---|
| 1 | 소개 | [ch01_introduction.md](ch01_introduction.md) | 23~28 |
| 2 | 기본 도구와 개념 | [ch02_preliminaries.md](ch02_preliminaries.md) | 29~50 |
| 3 | 토픽 | [ch03_topics.md](ch03_topics.md) | 51~70 |
| 4 | 서비스 | [ch04_services.md](ch04_services.md) | 71~80 |
| 5 | 액션 | [ch05_actions.md](ch05_actions.md) | 81~96 |
| 6 | 로봇과 시뮬레이터 | [ch06_robots_and_simulators.md](ch06_robots_and_simulators.md) | 97~118 |
| 7 | Wander-bot | [ch07_wander_bot.md](ch07_wander_bot.md) | 119~128 |
| 8 | Teleop-bot | [ch08_teleop_bot.md](ch08_teleop_bot.md) | 131~154 |
| 9 | 지도 만들기 | [ch09_building_maps.md](ch09_building_maps.md) | 155~170 |
| 10 | 지도 안에서 이동하기 | [ch10_navigation.md](ch10_navigation.md) | 171~184 |
| 11 | Chess-bot | [ch11_chess_bot.md](ch11_chess_bot.md) | 185~210 |
| 12 | Follow-bot | [ch12_follow_bot.md](ch12_follow_bot.md) | 213~228 |
| 13 | 순찰하기 | [ch13_on_patrol.md](ch13_on_patrol.md) | 229~244 |
| 14 | Stockroom-bot | [ch14_stockroom_bot.md](ch14_stockroom_bot.md) | 245~276 |
| 15 | 직접 만든 센서와 구동기 | [ch15_sensors_and_actuators.md](ch15_sensors_and_actuators.md) | 279~294 |
| 16 | 직접 만든 이동 로봇 1부 | [ch16_mobile_robot_part1.md](ch16_mobile_robot_part1.md) | 295~318 |
| 17 | 직접 만든 이동 로봇 2부 | [ch17_mobile_robot_part2.md](ch17_mobile_robot_part2.md) | 319~338 |
| 18 | 직접 만든 로봇팔 | [ch18_robot_arm.md](ch18_robot_arm.md) | 339~366 |
| 19 | 소프트웨어 라이브러리 붙이기 | [ch19_software_library.md](ch19_software_library.md) | 367~376 |
| 20 | 도구 | [ch20_tools.md](ch20_tools.md) | 379~394 |
| 21 | 로봇 동작 디버깅 | [ch21_debugging.md](ch21_debugging.md) | 395~418 |
| 22 | ROS 커뮤니티 | [ch22_community.md](ch22_community.md) | 419~424 |
| 23 | C++로 ROS 쓰기 | [ch23_cpp.md](ch23_cpp.md) | 425~436 |

## ROS 1 (원서) → ROS 2 Jazzy 공통 대응표

| 원서 (ROS 1) | ROS 2 Jazzy | 처음 다루는 장 |
|---|---|---|
| `roscore` (마스터) | 마스터가 없습니다. 노드들이 DDS 디스커버리로 서로를 직접 찾습니다. | 2 |
| ROS 자체 통신 계층 (TCPROS) | 교체할 수 있는 DDS 구현 (`RMW_IMPLEMENTATION`, 이 가이드는 Cyclone DDS) | 2 |
| catkin 워크스페이스, `catkin_make` | colcon 워크스페이스, `colcon build` | 2 |
| catkin 패키지 | `ament_python` 또는 `ament_cmake` 패키지 | 2 |
| `rosrun`, `roslaunch` | `ros2 run`, `ros2 launch` (launch 파일은 Python, XML, YAML) | 2 |
| `tf` | `tf2` (`tf2_ros`) | 2 |
| `rospy`, `roscpp` | `rclpy`, `rclcpp` | 3, 23 |
| latched 토픽 | QoS durability를 `transient_local`로 설정한 토픽 | 3 |
| `rosmsg`, `rossrv` | `ros2 interface` | 3 |
| `actionlib` | ROS 2에 기본으로 들어 있는 액션 (`rclpy.action`) | 5 |
| Gazebo Classic | Gazebo (gz-sim) + `ros_gz_bridge` | 6 |
| 전역 파라미터 서버, `rosparam` | 노드마다 자기 파라미터를 가짐, `ros2 param` | 8 |
| `rviz` | `rviz2` | 8 |
| `rosbag` | `ros2 bag` | 9 |
| gmapping | slam_toolbox | 9 |
| `move_base`, amcl | Nav2 | 10 |
| `rostest` | `launch_testing`, pytest | 20 |
