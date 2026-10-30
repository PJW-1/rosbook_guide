# 1장. 소개

- 원서: Chapter 1. Introduction, PDF p.23~28 (인쇄 쪽 = PDF 쪽 - 20)
- 선행 조건: 없음. 이 가이드의 실습 환경(README의 "실습 환경")이 준비되어 있으면 됩니다.
- 새로 설치할 것: 없음 (`ros-jazzy-desktop`에 `demo_nodes_py`가 들어 있습니다)

## 이 장에서 체감할 구조
ROS 2 시스템은 작은 프로그램(노드) 여러 개가 이름 붙은 통로(토픽)로 메시지를 주고받는 그래프입니다.
두 노드는 서로를 직접 알지 못하고, 같은 토픽 이름과 같은 메시지 타입을 쓴다는 사실만으로 연결됩니다.

```
[talker] --(/chatter, std_msgs/msg/String)--> [listener]
```

## 1. 목표와 개념

원서 1장은 ROS가 무엇이고 어떤 생각으로 만들어졌는지 소개하고, ROS 1 Indigo를 설치하는 장입니다 (원서 PDF p.24~25 철학, p.26~27 설치).

ROS는 로봇 소프트웨어를 만들기 위한 도구, 라이브러리, 관례의 모음입니다. 로봇 하나를 움직이려면 지도 작성, 경로 계획, 물체 인식 같은 어려운 문제를 모두 풀어야 하고, 한 팀이 전부를 처음부터 만들기는 어렵습니다. 그래서 ROS는 각 기능을 독립된 프로그램으로 나누고, 다른 사람이 만든 프로그램을 가져다 이어 붙일 수 있게 하는 데 초점을 둡니다.

이 생각은 ROS 2에서도 그대로입니다. 바뀐 것은 노드들이 서로를 찾고 데이터를 보내는 바닥 계층입니다. ROS 2를 새로 만든 이유 가운데, 이후 장에서 직접 체감하게 될 것은 다음 네 가지입니다.

| 이유 | ROS 1의 한계 | ROS 2의 방식 | 체감하는 장 |
|---|---|---|---|
| 마스터 없는 통신 | 모든 노드가 `roscore`(마스터)에 등록해야 서로를 찾습니다. 마스터가 죽으면 새 연결을 만들 수 없습니다. | 노드들이 DDS라는 표준 통신 미들웨어의 디스커버리 기능으로 서로를 직접 찾습니다. 띄워 둘 중앙 프로그램이 없습니다. | 1, 2 |
| 여러 로봇 | 마스터 하나가 시스템 하나를 묶으므로 로봇 여러 대를 한 네트워크에서 다루기 번거롭습니다. | `ROS_DOMAIN_ID`로 시스템을 나누고, 네임스페이스로 같은 노드를 여러 벌 띄웁니다. | 2 |
| 실시간성과 통신 품질 | 토픽은 TCP 연결 하나로 고정되어 있고, 전송 방식을 고를 여지가 적습니다. | 토픽마다 QoS(Quality of Service, 통신 품질 설정)를 고릅니다. 신뢰성, 늦게 접속한 쪽에 지난 메시지를 줄지 등을 정합니다. | 3 |
| 보안 | 인증과 암호화가 없습니다. | DDS Security 기반의 SROS2로 인증과 암호화를 켤 수 있습니다. | 이 가이드에서는 다루지 않음 |

DDS(Data Distribution Service)는 ROS 2가 직접 만든 것이 아니라 산업계에서 쓰던 통신 표준입니다. ROS 2는 그 위에 RMW(ROS MiddleWare)라는 얇은 계층을 두어서, DDS 구현체를 바꿔도 노드 코드는 그대로 쓸 수 있게 했습니다. 이 점은 2장에서 다시 봅니다.

비유: ROS 1의 `roscore`는 모든 사람이 먼저 들러야 하는 안내 데스크이고, ROS 2의 디스커버리는 같은 방에 들어온 사람들이 서로 이름표를 보고 직접 인사하는 방식입니다.

## 2. 원서(ROS 1)와 달라지는 점

| 원서 (ROS 1) | ROS 2 Jazzy | 이유와 주의점 |
|---|---|---|
| Ubuntu 14.04 + ROS Indigo, 직접 설치 | WSL2 Ubuntu 24.04 + ROS 2 Jazzy, 이미 설치됨 | 원서 p.26~27의 설치 명령은 실행하지 않습니다. |
| `source /opt/ros/indigo/setup.bash` 를 `~/.bashrc`에 추가 | `~/.bashrc`가 `/opt/ros/jazzy/setup.bash`와 `~/rosbook_ws/install/setup.bash`를 불러옴 | 이미 설정되어 있습니다. 1번 실습에서 확인만 합니다. |
| `rospy_tutorials`의 `talker`, `listener` (원서 2장) | `demo_nodes_py`의 `talker`, `listener` | ROS 2에서 처음 실행해 보기 좋은 예제 노드입니다. 1초에 한 번 발행합니다. |
| 노드를 띄우기 전에 `roscore` 실행 | 띄울 것이 없음 | 1-2 실습에서 `roscore` 없이 바로 연결되는 것을 확인합니다. |

## 3. 실습

### 실습 1-1. ROS 2 환경이 잡혀 있는지 확인하기

**준비**: 터미널 1개.

**직접 입력**:

```bash
printenv | grep -i ros
```

**관찰**: 다음 변수들이 보여야 합니다. 값은 PC마다 조금 다를 수 있습니다.

| 변수 | 기대하는 값 | 뜻 |
|---|---|---|
| `ROS_VERSION` | `2` | ROS 2 환경입니다. |
| `ROS_DISTRO` | `jazzy` | 배포판 이름입니다. |
| `ROS_PYTHON_VERSION` | `3` | Python 3을 씁니다. |
| `AMENT_PREFIX_PATH` | `/home/<사용자>/rosbook_ws/install/...:/opt/ros/jazzy` 형태 | ROS 2가 패키지를 찾는 경로 목록입니다. 2장에서 자세히 봅니다. |
| `RMW_IMPLEMENTATION` | `rmw_cyclonedds_cpp` | 통신 계층으로 Cyclone DDS를 씁니다. 이 환경에서 이 값을 쓰는 이유는 [부록](appendix_wsl_environment.md)에 있습니다. |
| `ROS_DOMAIN_ID` | 없을 수 있음 | 없으면 기본값 0을 씁니다. |

이어서 설치 상태를 점검합니다.

```bash
ros2 doctor
```

**관찰**: 마지막 줄에 `All 5 checks passed`처럼 모든 점검이 통과했다는 문장이 나오면 됩니다. 그 위에 `UserWarning: ... has been updated to a new version` 같은 경고가 여러 줄 나올 수 있습니다. 인터넷의 최신 패키지 버전과 비교한 결과일 뿐이라서 실습에는 영향이 없습니다.

`ros2 doctor`가 출력 없이 1분 넘게 멈춰 있으면 Ctrl-C로 멈추고 `ros2 daemon start`를 실행한 뒤 다시 시도합니다. daemon이 무엇인지는 2장에서, 이 PC에서 멈추는 이유는 [부록](appendix_wsl_environment.md)에서 다룹니다.

**생각해 볼 질문**: `ROS_DISTRO`가 비어 있다면 무엇이 빠진 것일까요?

### 실습 1-2. 첫 그래프 만들기: talker와 listener

**준비**: 터미널 3개를 엽니다. 이 장에서는 터미널 A, B, C라고 부릅니다.

**직접 입력**:

터미널 A:

```bash
ros2 run demo_nodes_py talker
```

터미널 B:

```bash
ros2 run demo_nodes_py listener
```

**관찰**: 터미널 A에는 1초마다 `Publishing: "Hello World: 0"`, `"Hello World: 1"` 같은 줄이, 터미널 B에는 `I heard: [Hello World: 0]` 같은 줄이 찍힙니다. 각 줄의 `[talker]`, `[listener]`는 노드 이름입니다.

```
[INFO] [1793109322.771191072] [talker]: Publishing: "Hello World: 0"
[INFO] [1793109322.787405872] [listener]: I heard: [Hello World: 0]
```

`roscore` 같은 중앙 프로그램을 띄우지 않았는데도 연결되었다는 점이 ROS 1과 가장 크게 다른 부분입니다.

**생각해 볼 질문**: listener를 먼저 띄우고 talker를 나중에 띄워도 연결될까요? 직접 순서를 바꿔 시험해 보세요.

### 실습 1-3. 그래프를 명령으로 들여다보기

**준비**: 터미널 A와 B에서 talker와 listener가 실행 중이어야 합니다. 터미널 C에서 입력합니다.

**직접 입력**:

```bash
ros2 node list
ros2 topic list -t
ros2 topic info -v /chatter
```

**관찰**:

`ros2 node list`는 지금 그래프에 있는 노드 이름을 보여 줍니다.

```
/listener
/talker
```

`ros2 topic list -t`는 토픽 이름과 메시지 타입을 함께 보여 줍니다. `-t`가 타입을 같이 출력하라는 옵션입니다.

```
/chatter [std_msgs/msg/String]
/parameter_events [rcl_interfaces/msg/ParameterEvent]
/rosout [rcl_interfaces/msg/Log]
```

`/chatter`가 두 노드를 잇는 토픽입니다. `/parameter_events`와 `/rosout`은 모든 노드가 자동으로 만드는 토픽으로, 각각 파라미터 변경 알림과 로그 전달에 쓰입니다.

`ros2 topic info -v /chatter`는 이 토픽에 누가 publisher(발행자)이고 누가 subscriber(구독자)인지, 각자 어떤 QoS로 연결했는지 보여 줍니다. 출력에서 다음 부분을 찾아봅니다.

```
Type: std_msgs/msg/String

Publisher count: 1

Node name: talker
...
Endpoint type: PUBLISHER
...
QoS profile:
  Reliability: RELIABLE
  ...
  Durability: VOLATILE
...
Subscription count: 1

Node name: listener
...
Endpoint type: SUBSCRIPTION
```

마지막으로 메시지 타입의 내용을 확인합니다.

```bash
ros2 interface show std_msgs/msg/String
```

주석 몇 줄 아래에 `string data` 한 줄이 보입니다. `/chatter`로 오가는 메시지는 문자열 필드 하나짜리라는 뜻입니다.

**생각해 볼 질문**: talker 터미널에서 Ctrl-C를 누른 뒤 `ros2 node list`와 `ros2 topic info /chatter`를 다시 실행하면 무엇이 달라질까요? listener 프로세스는 어떻게 될까요?

## 4. 일부러 망가뜨려 보기

| 바꿀 것 | 예상 증상 | 원인을 확인하는 명령 |
|---|---|---|
| talker를 Ctrl-C로 종료 | listener는 오류 없이 계속 실행되지만 새 메시지를 받지 못합니다. | `ros2 node list` (talker가 사라짐), `ros2 topic info /chatter` (Publisher count: 0) |
| listener를 `ROS_DOMAIN_ID=5 ros2 run demo_nodes_py listener` 로 실행 | talker가 돌고 있어도 아무것도 받지 못합니다. | 기본 도메인에서 `ros2 node list` 를 실행하면 listener가 보이지 않습니다. `ROS_DOMAIN_ID=5 ros2 node list --no-daemon` 에서는 보입니다. `--no-daemon`을 빼면 이 PC에서는 도메인 5용 daemon이 없어서 명령이 멈춥니다(2장 실습 2-2). |
| `ros2 run demo_nodes_py talkr` 처럼 실행 파일 이름 오타 | `No executable found` 오류 | `ros2 pkg executables demo_nodes_py` 로 실제 이름을 확인합니다. |

## 5. 확인 질문

<details><summary>Q1. ROS_DISTRO가 비어 있다면 무엇이 빠진 것인가요?</summary>

그 터미널에서 `/opt/ros/jazzy/setup.bash`가 source 되지 않은 것입니다. 이 스크립트가 `ROS_DISTRO`, `PATH`, `AMENT_PREFIX_PATH` 같은 환경 변수를 설정해야 `ros2` 명령과 패키지를 찾을 수 있습니다. `~/.bashrc`가 바뀌었거나, `bash`가 아닌 다른 셸을 쓰고 있는지 확인합니다.

</details>

<details><summary>Q2. listener를 먼저 띄우고 talker를 나중에 띄워도 연결되나요?</summary>

연결됩니다. 디스커버리는 계속 진행되므로, 나중에 나타난 노드도 같은 토픽 이름과 타입을 쓰면 자동으로 이어집니다. 다만 listener는 talker가 뜨기 전에 발행된 메시지를 받을 수 없습니다. 지난 메시지를 받으려면 3장에서 다루는 QoS durability 설정이 필요합니다.

</details>

<details><summary>Q3. talker를 끄면 listener는 어떻게 되나요?</summary>

listener는 종료되지 않고 그대로 기다립니다. 노드는 상대 노드를 알지 못하고 토픽만 바라보므로, publisher가 사라졌다고 해서 오류가 나지 않습니다. `ros2 topic info /chatter`의 `Publisher count`가 0으로 바뀐 것으로 상태를 확인할 수 있습니다. talker를 다시 띄우면 listener는 다시 메시지를 받습니다.

</details>

<details><summary>Q4. ROS 2에는 roscore가 없는데, 노드들은 어떻게 서로를 찾나요?</summary>

각 노드가 DDS 디스커버리로 "나는 이런 이름의 노드이고, 이런 토픽을 이런 타입으로 발행하거나 구독한다"는 정보를 같은 도메인의 다른 참여자에게 알립니다. 토픽 이름과 타입, QoS가 맞는 publisher와 subscriber가 있으면 둘이 직접 연결됩니다. 2장에서 이 과정을 더 자세히 봅니다.

</details>

## 6. 원서 대조 메모

- 원서 p.26~27의 설치 절차(Ubuntu 14.04, `apt-key`, `rosdep init`)는 ROS 1 Indigo 전용이라서 생략했습니다. 이 가이드의 환경은 이미 설치되어 있습니다.
- 원서 p.24의 "peer to peer" 설명은 ROS 2에서 더 철저해졌습니다. ROS 1은 데이터는 노드끼리 직접 보내도 이름 찾기는 `roscore`에 의존했지만, ROS 2는 이름 찾기까지 노드끼리 합니다.
- 원서 p.25의 다언어 지원은 ROS 2에서도 같은 생각입니다. ROS 2의 공식 클라이언트 라이브러리는 `rclcpp`(C++)와 `rclpy`(Python)이고, 이 가이드는 Python을 주로 쓰고 23장에서 C++를 다룹니다.
- 원서의 talker는 1초에 10번 발행하지만, `demo_nodes_py`의 talker는 1초에 1번 발행합니다 (실습 1-2 로그의 시각 차이로 확인).
- 보안(SROS2)은 원서 범위 밖이고 이 가이드에서도 다루지 않습니다.

## 7. 이 문서의 검증 상태

- 확인함 (2026-10-27, WSL2 Ubuntu 24.04, ROS 2 Jazzy, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`, 검증용 `ROS_DOMAIN_ID=21`):
  - `printenv | grep -i ros` 출력에 `ROS_VERSION=2`, `ROS_DISTRO=jazzy`, `ROS_PYTHON_VERSION=3`이 있음.
  - `ros2 doctor`: daemon이 떠 있을 때 약 3초 만에 `All 5 checks passed`. daemon이 없을 때는 같은 명령이 4분 30초 걸려 `All 3 checks passed`를 출력했음. 버전 비교 `UserWarning`은 stderr로 나옴.
  - talker와 listener를 별도 프로세스로 실행해 `I heard: [Hello World: N]` 수신, `ros2 node list`, `ros2 topic list -t`, `ros2 topic info -v /chatter`(RELIABLE, VOLATILE), `ros2 interface show std_msgs/msg/String` 출력.
  - talker를 SIGINT로 종료한 뒤 listener가 살아 있고 `ros2 node list`에 `/listener`만 남는 것.
  - 다른 `ROS_DOMAIN_ID`(22)로 띄운 listener가 도메인 21의 talker 메시지를 0건 받고, 각 도메인의 `ros2 node list`에 자기 노드만 보이는 것.
  - `ros-jazzy-demo-nodes-py` 설치됨 (`apt-cache policy`: 0.33.11).
  - `ros2 run demo_nodes_py talkr`의 오류 문구 `No executable found`.
- 확인 못 함:
  - `ROS_DOMAIN_ID`를 설정하지 않은 기본 도메인 0에서의 실행. 검증은 다른 작업과 섞이지 않도록 도메인 21에서 했습니다.
  - 학습자의 `~/.bashrc`에 `RMW_IMPLEMENTATION`이 실제로 추가되었는지. 이 문서는 추가되어 있다고 전제합니다.
- 결함 수정(2026-10-31): 4절 도메인 행의 `ROS_DOMAIN_ID=5 ros2 node list`에 `--no-daemon`을 붙였습니다. 이 PC에서는 그 도메인용 daemon이 없으면 이 명령이 멈추기 때문입니다. 근거는 `checks/domain_no_daemon.sh`의 실행 결과입니다. `--no-daemon`을 붙이면 1초 만에 `/listener`가 보였고, 붙이지 않으면 20초 안에 끝나지 않았습니다. README에 있던 환경 설명을 `appendix_wsl_environment.md`로 옮기면서 이 장의 참조도 부록으로 바꿨습니다.
