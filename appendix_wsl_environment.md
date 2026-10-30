# 부록. 이 가이드의 실습 환경(WSL2) 메모

이 부록은 이 가이드를 쓰고 검증한 PC의 환경, 곧 Windows 11의 WSL2 Ubuntu 24.04를 `networkingMode=mirrored`로 설정한 환경에서만 생기는 문제와 그 해결 방법을 모은 곳입니다. 작성자와 같이 WSL2를 mirrored 네트워크 모드로 쓰는 학습자는 장 실습을 시작하기 전에 읽어 둡니다. Ubuntu를 PC에 직접 설치해 쓰는 학습자는 훑어보기만 해도 되고, 각 장에서 이 부록을 가리킬 때 다시 찾아보면 됩니다.

## 왜 Fast DDS 대신 Cyclone DDS를 쓰나요

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

이 PC의 WSL은 `networkingMode=mirrored`로 설정되어 있습니다. 이 환경에서 Fast DDS로 `demo_nodes_cpp`의 talker와 listener를 띄웠더니, `ros2 topic list`에는 토픽이 보였지만 listener는 10초 동안 메시지를 한 건도 받지 못했습니다. 탐색 범위를 `LOCALHOST`나 `SUBNET`으로 바꿔도, UDP만 쓰도록 해도 결과가 같았습니다.

다만 Fast DDS가 이 환경에서 항상 실패하는 것은 아닙니다. 가이드를 검증하는 도중 `LOCALHOST`에서 메시지가 도착한 적이 있어서, C++와 Python 데모, 기본 범위와 `LOCALHOST`를 섞어 16번 다시 시험했습니다. 15번은 한 건도 받지 못했고, 1번(Python, `LOCALHOST`)만 받았습니다. 같은 날 Cyclone DDS는 4번 모두 받았습니다. 될 때와 안 될 때가 섞이면, 메시지가 오지 않을 때 내 코드가 틀린 것인지 통신이 안 되는 것인지 가릴 수 없습니다. 구조를 익히는 데 방해가 되므로 이 가이드는 Cyclone DDS를 씁니다. mirrored 네트워크 모드가 원인으로 보이지만, NAT 모드로 되돌려서 확인하지는 않았습니다.

Cyclone DDS 패키지(`ros-jazzy-rmw-cyclonedds-cpp`)는 이 PC에 ROS 2 Jazzy와 함께 이미 설치되어 있습니다. 다른 PC에서 따라 한다면 `RMW_IMPLEMENTATION`을 설정하기 전에 `sudo apt install ros-jazzy-rmw-cyclonedds-cpp`로 먼저 설치합니다.

RMW를 바꿔도 노드 코드, 토픽과 서비스 이름, QoS, launch 파일, `ros2` 명령은 모두 그대로입니다. 원서의 실습 내용도 영향을 받지 않습니다. 다만 다음 세 가지는 알아 두어야 합니다.

- 서로 통신하는 터미널은 모두 같은 RMW를 써야 합니다. `.bashrc`를 고치기 전에 열어 둔 터미널은 닫고 새로 엽니다.
- RMW를 바꾼 뒤에는 `ros2 daemon stop`과 `ros2 daemon start`를 이어서 실행해 daemon을 다시 띄웁니다. 백그라운드에 떠 있던 daemon은 예전 RMW로 동작하고 있기 때문입니다. daemon은 바로 아래 절에서 설명합니다.
- 인터넷 자료에 나오는 Fast DDS 전용 설정(XML 프로파일, Discovery Server, `FASTDDS_` 로 시작하는 환경 변수)은 이 환경에 적용되지 않습니다.

현재 쓰고 있는 RMW는 다음 명령으로 확인합니다. 2장에서 두 RMW를 직접 바꿔 가며 비교해 봅니다.

```bash
ros2 doctor --report | grep -i middleware
```

## `ros2` 명령이 2분 넘게 멈출 때: daemon 먼저 띄우기

`ros2 topic list`나 `ros2 node list` 같은 명령은 매번 네트워크를 처음부터 탐색하지 않습니다. 백그라운드에 떠 있는 `ros2 daemon`이라는 프로세스가 탐색 결과를 계속 모아 두고, CLI는 localhost의 TCP 포트(11511 + `ROS_DOMAIN_ID`)로 daemon에게 결과를 물어봅니다. 원래는 daemon이 없으면 연결이 곧바로 거절되고, CLI가 daemon을 새로 띄운 뒤 결과를 보여 줍니다.

이 WSL에서는 daemon이 없을 때 연결이 거절되지 않고, 응답을 기다리다가 시간 초과로 끝납니다. mirrored 네트워크 모드에서 생기는 현상으로 보입니다. 직접 재어 보니 daemon이 없는 상태에서 `ros2 daemon status`와 `ros2 topic list`는 각각 약 2분 17초 동안 멈췄다가 Python Traceback을 내고 끝났고, daemon도 새로 뜨지 않았습니다. WSL을 새로 시작한 직후나 `ros2 daemon stop`을 실행한 뒤가 바로 이런 상태입니다. `ros2 doctor`, `ros2 topic echo`, `ros2 daemon stop`도 같은 방식으로 멈춥니다.

해결 방법은 CLI를 쓰기 전에 daemon을 먼저 띄우는 것입니다. `ros2 daemon start`는 연결을 시도하지 않고 포트를 직접 열어 보는 방식이라 1초 안에 끝나고, daemon이 이미 떠 있으면 그렇다고 알려 주기만 합니다.

```bash
ros2 daemon start
```

매번 입력하기 번거로우면 `~/.bashrc`의 맨 끝에 다음 한 줄을 추가합니다. 터미널을 열 때마다 1초 정도 더 걸리지만, daemon이 항상 떠 있게 됩니다. 이 줄은 ROS의 `setup.bash`를 source 하는 줄과 `RMW_IMPLEMENTATION` 줄보다 반드시 아래에 있어야 합니다. 그 위에 두면 `ros2` 명령을 아직 찾을 수 없거나, daemon이 Fast DDS로 뜹니다. 출력을 버리는 줄이라 실패해도 아무것도 보이지 않으므로, 추가한 뒤 새 터미널에서 `ros2 topic list`가 바로 끝나는지 한 번 확인합니다.

```bash
ros2 daemon start > /dev/null 2>&1
```

알아 둘 점은 다음과 같습니다.

- daemon을 다시 띄워야 할 때(RMW를 바꾼 뒤, CLI 결과가 실제 상태와 다르게 보일 때)는 `ros2 daemon stop` 직후에 `ros2 daemon start`를 실행합니다. `stop`은 daemon이 떠 있을 때만 바로 끝납니다.
- `ros2 daemon status`는 쓰지 않습니다. daemon이 없을 때 "없다"고 알려 주는 대신 2분 넘게 멈춥니다.
- daemon은 CLI의 질문을 2시간 동안 한 번도 받지 않으면 스스로 꺼집니다(`ros2cli/daemon/__init__.py`의 `serve()` 기본값). `.bashrc`의 줄은 터미널을 열 때만 실행되므로, 오래 쉬었다가 같은 터미널에서 명령이 멈추면 Ctrl+C 뒤 `ros2 daemon start`를 입력합니다.
- 이미 멈춘 명령은 Ctrl+C로 끊고 `ros2 daemon start`를 실행한 뒤 다시 입력합니다.
- `ros2 topic list --no-daemon`처럼 `--no-daemon`을 붙이면 daemon을 거치지 않고 그 명령이 직접 탐색합니다. 조금 느리지만 daemon 상태와 상관없이 동작합니다.

### daemon이 질문을 받는 방식과 노드 이름

2장에서 옮겨 온 내용입니다. 위의 문제가 왜 생기는지 이해하는 데 필요하지만, ROS 2의 구조를 익히는 데 꼭 필요한 내용은 아닙니다.

- daemon은 `127.0.0.1`의 TCP 포트 `11511 + ROS_DOMAIN_ID`에서 XML-RPC라는 방식으로 질문을 받습니다. 도메인 0이면 11511이고, 도메인 번호만큼 더해집니다. 도메인마다 포트가 다르므로 daemon도 도메인마다 따로 뜹니다. DDS가 아닌 localhost 연결이라서, 노드끼리 메시지를 주고받는 경로와는 별개입니다.
- daemon 자신도 ROS 2 노드라서 그래프에 `/_ros2cli_daemon_0_<16진수>`라는 이름으로 나타납니다. 앞의 `_ros2cli`는 CLI가 만드는 노드의 공통 접두사이고, `0`은 도메인 번호, 끝의 16진수는 띄울 때마다 새로 만드는 고유 번호입니다. 이름의 어느 부분이든 `_`로 시작하면 숨은 노드로 취급되어, `ros2 node list`는 `-a` 없이는 이 노드를 보여 주지 않습니다(2장 실습 2-2).
- daemon은 질문을 받을 때마다 타이머를 다시 시작하고, 2시간 동안 질문이 하나도 없으면 스스로 종료합니다.
- daemon을 쓰지 않을 때(`--no-daemon`, 또는 daemon이 없을 때) CLI가 이번 명령만을 위해 만드는 직접 노드의 이름은 `_ros2cli_<프로세스 번호>`입니다.

### 2장 실습에서의 주의점

2장 실습 2-2와 "일부러 망가뜨려 보기"에 있던 이 PC 전용 설명을 옮겨 왔습니다.

- 이 WSL은 `127.0.0.1`의 닫힌 포트로 연결을 시도하면 바로 거부되지 않고 시간이 다 될 때까지 기다립니다. `ros2` CLI는 daemon이 떠 있는지 확인하려고 그 포트에 연결해 보므로, 그 도메인에 daemon이 없으면 `ros2 node list`, `ros2 topic list`, `ros2 doctor` 같은 명령이 약 2분 17초 동안 멈췄다가 Python Traceback을 내고 끝납니다. 이럴 때는 Ctrl-C로 멈추고 `ros2 daemon start`를 먼저 실행합니다. `ros2 daemon start`는 daemon이 없어도 1초 안에 끝납니다.
- `ros2 daemon stop`을 쓴 뒤에는 바로 `ros2 daemon start`를 붙여서, daemon이 없는 상태로 두지 않습니다.
- 실습 2-2의 `ROS_DOMAIN_ID=5 ros2 node list`도 도메인 5용 daemon이 따로 필요하므로, 멈추면 `ROS_DOMAIN_ID=5 ros2 node list --no-daemon`으로 실행합니다.
- `ros2 daemon stop` 뒤에 `ros2 daemon start` 없이 `ros2 node list`를 실행하면, 이 PC에서는 약 2분 동안 출력 없이 멈췄다가 Traceback을 내고 끝납니다. 그동안에도 노드끼리는 계속 통신합니다. Ctrl-C로 끊고 `ros2 daemon start`를 실행한 뒤 다시 `ros2 node list`를 입력합니다.

## 그래픽과 시뮬레이션 문제 해결

- `GALLIUM_DRIVER=d3d12`를 설정하면 Gazebo가 GPU로 렌더링합니다. 이 설정이 없으면 CPU로 렌더링하는 llvmpipe가 쓰이고, 시뮬레이션이 실제 시간보다 몇 배에서 수십 배 느리게 흘러갑니다. 지금 쓰는 렌더러는 `glxinfo -B | grep -i "renderer string"`으로 확인합니다.
- Gazebo 창이 뜨지 않거나 GUI가 비정상적으로 종료되면, 그 터미널에서만 CPU 렌더링으로 바꿔서 실행해 봅니다. 느리지만 안정적입니다.

  ```bash
  GALLIUM_DRIVER=llvmpipe ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
  ```
- `QT_QPA_PLATFORM=wayland`는 설정하지 않습니다. d3d12와 함께 쓰면 Gazebo GUI가 렌더링 창을 만들지 못합니다.
- 시뮬레이션을 Ctrl+C로 끌 때 Gazebo 서버가 `Segmentation fault`를 출력할 수 있습니다. 종료 과정에서만 생기는 현상이라 실습에는 영향이 없습니다.
- 시뮬레이션을 껐는데도 로봇 토픽이 계속 보이면, 이전 Gazebo 서버가 남아 있는지 `pgrep -af "gz sim"`으로 확인합니다.
