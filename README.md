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

각 장의 "이 장에서 체감할 구조"와 "목표와 개념"에는 그림, 한두 줄짜리 코드 예시, 패키지 폴더 구조, 실무 메모가 들어 있습니다. 실습에 들어가기 전에 이 부분을 읽고, 무엇이 어떻게 연결되는지 그림으로 먼저 잡아 두면 실습이 훨씬 잘 들어옵니다. 1절의 코드 예시는 읽기만 하고, 직접 입력은 3절 실습에서 합니다.

그림은 mermaid 형식으로 그렸습니다. GitHub에서 문서를 열면 그림으로 보입니다. VS Code의 Markdown 미리 보기에서 보려면 "Markdown Preview Mermaid Support" 확장을 설치합니다. 확장이 없으면 그림 대신 그림을 그리는 글자가 그대로 보입니다.

1~5장은 개념을 이미 읽었더라도 ROS 2 코드를 처음 직접 작성하는 단계이므로 순서대로 실습하기를 권합니다.

## 실습 환경

| 항목 | 내용 |
|---|---|
| OS | Windows 11 + WSL2 Ubuntu 24.04 |
| ROS | ROS 2 Jazzy (`/opt/ros/jazzy`) |
| 워크스페이스 | `~/rosbook_ws` (패키지는 `~/rosbook_ws/src/`) |
| 시뮬레이터 | Gazebo Harmonic (gz-sim 8) + `ros_gz_bridge` |
| 로봇 | TurtleBot3 waffle_pi 시뮬레이션 (LiDAR와 카메라 탑재). 실물 로봇은 쓰지 않습니다. |
| 통신 미들웨어 (RMW) | Cyclone DDS (`rmw_cyclonedds_cpp`). Jazzy의 기본값인 Fast DDS를 쓰지 않는 이유는 [부록](appendix_wsl_environment.md)에 적었습니다. |
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

### 이 환경에서 꼭 알아 둘 점

이 환경에서만 생기는 문제와 자세한 이유는 [부록. 이 가이드의 실습 환경(WSL2) 메모](appendix_wsl_environment.md)에 모았습니다. 실습을 시작하기 전에 다음만은 기억해 둡니다.

- 터미널에서 `ros2` 명령을 쓰기 전에 `ros2 daemon start`로 daemon을 먼저 띄웁니다. 이 환경에서는 daemon이 없으면 `ros2` 명령이 약 2분 동안 멈췄다가 실패합니다.
- 이 가이드는 Jazzy의 기본값인 Fast DDS 대신 Cyclone DDS를 씁니다. 이 환경에서 Fast DDS로는 메시지가 안정적으로 전달되지 않았기 때문입니다.
- RMW를 바꾸거나 CLI 결과가 실제와 다르게 보이면 `ros2 daemon stop` 직후에 `ros2 daemon start`를 실행합니다.
- Gazebo가 GPU로 렌더링하도록 `GALLIUM_DRIVER=d3d12`를 설정합니다. 이 설정이 없으면 시뮬레이션이 실제 시간보다 크게 느려집니다.

## 목차

| 장 | 제목 | 문서 | 원서 PDF 쪽 | 검증 상태 |
|---|---|---|---|---|
| 1 | 소개 | [ch01_introduction.md](ch01_introduction.md) | 23~28 | 검증됨 (0/3) |
| 2 | 기본 도구와 개념 | [ch02_preliminaries.md](ch02_preliminaries.md) | 29~50 | 일부 미검증 (4/10) |
| 3 | 토픽 | [ch03_topics.md](ch03_topics.md) | 51~70 | 검증됨 (0/7) |
| 4 | 서비스 | [ch04_services.md](ch04_services.md) | 71~80 | 검증됨 (0/5) |
| 5 | 액션 | [ch05_actions.md](ch05_actions.md) | 81~96 | 일부 미검증 (1/5) |
| 6 | 로봇과 시뮬레이터 | [ch06_robots_and_simulators.md](ch06_robots_and_simulators.md) | 97~118 | 대부분 미검증 (5/7) |
| 7 | Wander-bot | [ch07_wander_bot.md](ch07_wander_bot.md) | 119~128 | 대부분 미검증 (3/5) |
| 8 | Teleop-bot | [ch08_teleop_bot.md](ch08_teleop_bot.md) | 131~154 | 일부 미검증 (3/8) |
| 9 | 지도 만들기 | [ch09_building_maps.md](ch09_building_maps.md) | 155~170 | 일부 미검증 (3/6) |
| 10 | 지도 위에서 스스로 움직이기 | [ch10_navigation.md](ch10_navigation.md) | 171~184 | 대부분 미검증 (5/6) |
| 11 | 체스 두는 로봇팔 (Chess-bot) | [ch11_chess_bot.md](ch11_chess_bot.md) | 185~209 | 대부분 미검증 (10/10) |
| 12 | 카메라로 선 따라가기 | [ch12_follow_bot.md](ch12_follow_bot.md) | 213~228 | 대부분 미검증 (5/6) |
| 13 | 순찰하기 | [ch13_on_patrol.md](ch13_on_patrol.md) | 229~244 | 대부분 미검증 (5/8) |
| 14 | 창고에서 물건 가져오기 | [ch14_stockroom_bot.md](ch14_stockroom_bot.md) | 245~276 | 대부분 미검증 (4/7) |
| 15 | 나만의 센서와 액추에이터 | [ch15_sensors_and_actuators.md](ch15_sensors_and_actuators.md) | 279~294 | 일부 미검증 (1/8) |
| 16 | 나만의 이동 로봇 1부 | [ch16_mobile_robot_part1.md](ch16_mobile_robot_part1.md) | 295~318 | 일부 미검증 (3/7) |
| 17 | 나만의 이동 로봇 2부 | [ch17_mobile_robot_part2.md](ch17_mobile_robot_part2.md) | 319~338 | 일부 미검증 (2/6) |
| 18 | 나만의 로봇팔 | [ch18_robot_arm.md](ch18_robot_arm.md) | 339~366 | 대부분 미검증 (6/7) |
| 19 | 소프트웨어 라이브러리 붙이기 | [ch19_software_library.md](ch19_software_library.md) | 367~376 | 일부 미검증 (2/6) |
| 20 | 도구 | [ch20_tools.md](ch20_tools.md) | 379~394 | 일부 미검증 (1/8) |
| 21 | 로봇 동작 디버깅 | [ch21_debugging.md](ch21_debugging.md) | 395~418 | 일부 미검증 (6/8) |
| 22 | ROS 커뮤니티 | [ch22_community.md](ch22_community.md) | 419~424 | 검증됨 (0/4) |
| 23 | ROS 2에서 C++ 쓰기 | [ch23_cpp.md](ch23_cpp.md) | 425~435 | 검증됨 (0/5) |
| 부록 | 이 가이드의 실습 환경(WSL2) 메모 | [appendix_wsl_environment.md](appendix_wsl_environment.md) | 해당 없음 | 해당 없음 |

"검증 상태"는 문서를 쓸 때 실습을 실제로 실행해 확인한 정도입니다. 괄호 안의 숫자는 "미검증 실습 표시가 붙은 실습 수/전체 실습 수"입니다.

- 검증됨: 모든 실습을 실행해 관찰 항목을 확인했습니다. "일부러 망가뜨려 보기"의 몇몇 행에는 `(미검증)`이 붙어 있을 수 있습니다.
- 일부 미검증: 일부 실습이나 실습의 일부(주로 GUI 화면)를 확인하지 못했습니다.
- 대부분 미검증: 시뮬레이션이나 GUI가 필요한 핵심 실습의 절반 넘게 확인하지 못했습니다. 관찰 항목의 상당수는 설치된 파일과 소스 코드를 읽고 쓴 예상이므로, 실제 결과와 다르면 문서가 틀렸을 수 있습니다.

확인하지 못한 실습에는 제목 바로 아래에 "미검증 실습" 표시가 있고, 그 표시에 확인하지 못한 범위가 적혀 있습니다. 무엇을 어떻게 확인했는지는 각 장 7절 "이 문서의 검증 상태"에 접혀 있습니다. 판단 기준은 [CONVENTIONS.md](CONVENTIONS.md)의 9절에 있습니다.

### 기본기부터 다지는 순서

ROS 2의 기본 구조를 먼저 탄탄히 익히고 싶다면 1~5장 → 20장 → 21장 → 23장 순서로 공부합니다. 이 장들은 시뮬레이터 없이 터미널만으로 실습할 수 있고(21장의 실습 21-6만 시뮬레이터를 씁니다), 대부분의 실습을 실행해 확인했습니다. 이 순서를 마친 뒤 6장부터 시뮬레이션 장으로 넘어가면 로봇 동작이 기대와 다를 때 원인을 스스로 좁혀 갈 수 있습니다.

## 검증 스크립트 (`checks/`)

문서를 고치게 만든 동작이나 오해하기 쉬운 동작은 `checks/` 폴더의 스크립트로 다시 확인할 수 있습니다. 스크립트는 임시 폴더와 전용 `ROS_DOMAIN_ID`를 쓰므로 `~/rosbook_ws`와 실행 중인 노드를 건드리지 않습니다. 실행 방법과 각 스크립트가 확인하는 내용은 [checks/README.md](checks/README.md)에 있습니다. 실습을 대신하는 도구가 아니므로, 실습은 지금처럼 직접 입력하고 문서와 결과가 다를 때 참고용으로 씁니다.

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
