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

`~/.bashrc`가 새 터미널을 열 때마다 ROS 2와 워크스페이스 환경을 불러오므로, 터미널을 새로 열면 바로 `ros2` 명령을 쓸 수 있습니다.

TurtleBot3 시뮬레이션은 다음 명령으로 띄웁니다.

```bash
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```

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
