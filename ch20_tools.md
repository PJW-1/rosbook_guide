# 20장. 도구

- 원서: Chapter 20. Tools, PDF p.379~394 (인쇄 쪽 = PDF 쪽 - 20)
- 선행 조건: 3장의 `basics` 패키지에 `topic_publisher`(토픽 `counter` 에 `std_msgs/msg/Int32` 를 0.5초마다 발행, 노드 이름 `topic_publisher`)와 `topic_subscriber`(같은 토픽을 받아 로그로 출력, 노드 이름 `topic_subscriber`)가 있는 상태. 4장의 `basics_interfaces/srv/WordCount` 를 알고 있으면 좋습니다.
- 새로 설치할 것: 없음 (`demo_nodes_cpp`, `launch_testing` 은 ROS 2 Jazzy desktop 설치에 들어 있습니다)

## 이 장에서 체감할 구조

ROS 2에는 중앙 서버(master)가 없고, 노드끼리 DDS로 서로를 찾습니다. `ros2` 명령줄 도구도 하나의 노드로서 그래프에 잠깐 참여해 정보를 모읍니다.
파라미터는 중앙 저장소가 아니라 각 노드가 자기 것을 들고 있고, 노드가 선언한 이름만 존재합니다.
launch는 여러 노드와 그 설정(이름, 재매핑, 파라미터)을 파일 하나로 묶고, launch_testing은 그 묶음 위에서 테스트를 돌립니다.

## 1. 목표와 개념

이 장의 목표는 ROS 2 시스템을 띄우고, 설정하고, 들여다보고, 시험하는 명령줄 도구를 손에 익히는 것입니다. 원서가 다루는 도구 묶음(roscore, rosparam, roscd, rosrun, roslaunch, rostest, 그리고 rosnode/rostopic/rosmsg/rosservice/rossrv)을 ROS 2의 대응 도구로 하나씩 바꿔 가며 실습합니다. rosbag, rqt 계열 도구는 원서와 같이 21장에서 다룹니다 (원서 PDF p.379).

ROS 2에서 바뀐 핵심은 두 가지입니다.

1. **master가 없습니다.** ROS 1에서는 모든 노드가 master에 이름과 주소를 등록하고 서로를 찾았습니다 (원서 PDF p.379~380). ROS 2에서는 DDS(Data Distribution Service: 노드들이 네트워크에 자기를 알리고 서로를 직접 찾는 통신 미들웨어)의 discovery(발견) 과정으로 노드가 서로를 찾습니다. 그래서 `roscore` 를 먼저 띄울 필요가 없습니다.
2. **파라미터 서버가 없습니다.** 파라미터는 각 노드 안에 있고, 노드가 `declare_parameter` 로 선언한 이름만 존재합니다. 바깥에서는 그 노드가 제공하는 파라미터 서비스로 읽고 씁니다.

master가 없는 대신 `ros2` 명령은 매번 그래프를 새로 발견해야 해서 느릴 수 있습니다. 이를 줄이려고 **ros2 daemon**(데몬: 백그라운드에서 계속 떠서 발견한 노드와 토픽 정보를 모아 두는 프로세스)을 씁니다. `ros2 node list` 같은 명령은 daemon이 떠 있으면 daemon에게 물어보고 바로 답을 받습니다. daemon은 master와 달리 없어도 노드끼리의 통신에는 아무 영향이 없습니다.

비유: ROS 1의 master는 모든 전화번호를 관리하는 교환원이고, ROS 2의 DDS discovery는 같은 방에 들어온 사람들이 서로 큰 소리로 자기소개를 하는 방식입니다. daemon은 그 자기소개를 계속 받아 적어 두는 메모 담당입니다.

## 2. 원서(ROS 1)와 달라지는 점

| 원서 (ROS 1) | ROS 2 Jazzy | 이유와 주의점 |
|---|---|---|
| `roscore` (master, 파라미터 서버, rosout 노드) | 없음. 필요하면 `ros2 daemon start` | 노드는 DDS discovery로 서로를 찾습니다. daemon은 명령줄 도구의 속도를 위한 캐시일 뿐입니다. 이 가이드의 환경에서는 daemon이 없을 때 명령이 멈출 수 있으므로 README의 안내대로 daemon을 미리 띄우고, `ros2 daemon stop` 을 했다면 바로 `ros2 daemon start` 를 합니다. |
| `rosnode cleanup` (죽은 노드 등록 정리) | 해당 명령 없음 | 등록 표가 없으므로 정리할 것도 없습니다. 죽은 노드는 discovery 정보가 만료되면 목록에서 사라집니다. |
| `rosparam set/get/delete/dump/load` (전역 파라미터 서버) | `ros2 param set/get/delete/dump/load/list/describe <노드>` | 모든 명령에 대상 노드 이름이 붙습니다. 노드가 선언하지 않은 파라미터는 기본적으로 읽을 수도 쓸 수도 없습니다. |
| 슬래시로 구분한 이름 `my_dict/message` | 점으로 구분한 이름 `my_dict.message` | YAML의 중첩 구조가 점 구분 이름으로 펼쳐집니다. |
| `roscd`, `rosed` | `ros2 pkg prefix`, `colcon_cd` | `ros2 pkg prefix` 는 설치 위치를 알려 주고, `colcon_cd` 는 소스 위치로 이동합니다. `rosed` 에 해당하는 명령은 없습니다. |
| `rosrun pkg node` | `ros2 run pkg executable --ros-args ...` | 실행 파일은 `setup.py` 의 `console_scripts`(Python)나 CMake의 `install(TARGETS ...)`(C++)로 등록된 것만 보입니다. 재매핑과 파라미터는 `--ros-args` 뒤에 씁니다. |
| roslaunch XML (`.launch`) | launch 파일을 Python, XML, YAML 중 하나로 작성 | XML 태그 이름이 조금 바뀌었습니다(`type` 대신 `exec`, `$(find pkg)` 대신 `$(find-pkg-share pkg)`, 인자는 `$(var name)`). |
| launch가 노드 출력을 기본으로 로그 파일로 보냄, `output="screen"` 필요 | 노드의 로그 출력(`get_logger()`)은 `output` 지정 없이도 화면에 나옴 | ROS 2 로그는 기본으로 표준 오류(stderr)에 찍히고 launch가 이를 화면에 보여 줍니다. `print()` 같은 표준 출력은 `output='screen'` 이 있어야 화면에 나옵니다. |
| launch가 모든 파라미터를 노드 실행 전에 서버에 넣음 | launch가 파라미터를 임시 YAML 파일로 만들어 `--params-file` 로 노드에 넘김 | 노드가 그 이름을 선언하지 않았으면 값은 무시됩니다(실습 20-5). |
| `rostest` + `<test>` 태그 | `launch_testing` + pytest, `colcon test` | 테스트 파일 하나에 "띄울 노드"와 "검사할 내용"을 함께 씁니다. |
| `self.assert_(...)` | `self.assertTrue(...)` 등 | `assert_` 는 Python 3.12(Ubuntu 24.04의 Python)에서 제거되었습니다. |
| `rosnode/rostopic/rosservice` + `rosmsg/rossrv` | `ros2 node/topic/service` + `ros2 interface` | 메시지, 서비스, 액션 정의 보기가 `ros2 interface` 하나로 합쳐졌습니다. |
| `rosnode ping`, `rosnode kill` | 해당 명령 없음 | `ros2 node` 의 하위 명령은 `info` 와 `list` 뿐입니다. 노드를 끄려면 그 노드의 터미널에서 Ctrl+C를 누릅니다. |

## 3. 실습

이 장의 실습은 모두 같은 터미널 준비로 시작합니다. 새 터미널을 열 때마다 다음을 입력합니다(README에서 `~/.bashrc` 에 넣은 경우 생략).

```bash
source ~/rosbook_ws/install/setup.bash
```

### 실습 20-1. master 없이 노드 찾기와 daemon

**준비**: 터미널 두 개

**직접 입력**:

터미널 1:

```bash
ros2 run basics topic_publisher
```

터미널 2:

```bash
ros2 node list
ros2 daemon stop
ros2 daemon start
ros2 node list
ros2 node list --no-daemon --spin-time 3
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `ros2 run basics topic_publisher` | master를 띄우지 않고 바로 노드를 실행합니다. |
| `ros2 node list` | daemon이 모아 둔 정보로 노드 목록을 보여 줍니다. daemon이 떠 있지 않으면 먼저 daemon을 띄우고 물어봅니다. |
| `ros2 daemon stop` | daemon을 끕니다. 노드끼리의 통신에는 영향이 없습니다. |
| `ros2 daemon start` | daemon을 다시 띄웁니다. 이 가이드의 환경에서는 stop 뒤에 반드시 바로 start를 입력합니다. |
| `--no-daemon --spin-time 3` | daemon을 쓰지 않고, 이 명령이 직접 3초 동안 discovery를 해서 결과를 냅니다. daemon이 의심스러울 때 비교용으로 씁니다. |

**관찰**:
- `ros2 daemon start` 는 `The daemon has been started` 를 출력합니다.
- daemon을 껐다 켠 직후의 `ros2 node list` 는 아직 정보를 다 모으지 못해 목록이 비어 있을 수 있습니다. 몇 초 뒤 다시 입력하면 `/topic_publisher` 가 나옵니다.
- `--no-daemon` 판은 daemon 없이도 `/topic_publisher` 를 보여 줍니다. 노드를 찾는 일 자체에는 daemon이 필요 없다는 뜻입니다.

**생각해 볼 질문**: 원서는 master가 죽으면 새 노드를 띄울 수 없다고 설명합니다 (원서 PDF p.380). ROS 2에서 daemon이 죽으면 새 노드끼리의 통신은 어떻게 될까요?

### 실습 20-2. 파라미터 다루기

**준비**: 터미널 두 개. `demo_nodes_cpp` 패키지의 `parameter_blackboard` 노드는 어떤 이름의 파라미터든 받아 주는 "게시판" 노드라서, 원서의 전역 파라미터 서버 실습을 흉내 내기 좋습니다.

**직접 입력**:

터미널 1:

```bash
ros2 run demo_nodes_cpp parameter_blackboard
```

터미널 2:

```bash
ros2 param set /parameter_blackboard my_param 4.2
ros2 param get /parameter_blackboard my_param
ros2 param describe /parameter_blackboard my_param
ros2 param set /parameter_blackboard my_dict.message "Hello world"
ros2 param set /parameter_blackboard my_dict.x 4.2
ros2 param list /parameter_blackboard
ros2 param delete /parameter_blackboard my_param
ros2 param get /parameter_blackboard my_param
cd ~
ros2 param dump /parameter_blackboard > data.yaml
cat data.yaml
```

`data.yaml` 을 편집기로 열어 `Hello world` 를 `Goodbye world` 로 바꾼 뒤 이어서 입력합니다.

```bash
ros2 param load /parameter_blackboard data.yaml
ros2 param get /parameter_blackboard my_dict.message
```

마지막으로 터미널 1의 노드를 Ctrl+C로 끄고, 파일을 주면서 다시 띄웁니다.

```bash
ros2 run demo_nodes_cpp parameter_blackboard --ros-args --params-file ~/data.yaml
```

터미널 2:

```bash
ros2 param get /parameter_blackboard my_dict.message
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `ros2 param set /parameter_blackboard my_param 4.2` | 노드 이름을 먼저 쓰고 파라미터 이름과 값을 씁니다. 값은 YAML로 해석되므로 `4.2` 는 double이 됩니다. |
| `ros2 param describe` | 파라미터의 타입과 제약 조건을 보여 줍니다. |
| `my_dict.message` | ROS 2는 중첩 이름을 점으로 구분합니다. 원서의 `my_dict/message` 에 해당합니다. |
| `ros2 param delete` | 파라미터를 지웁니다. 이 노드는 이름을 자유롭게 받는 노드라 지울 수 있습니다. |
| `ros2 param dump ... > data.yaml` | 노드의 모든 파라미터를 YAML로 출력합니다. 화면에 찍히므로 파일로 저장하려면 `>` 로 보냅니다. |
| `ros2 param load` | YAML 파일의 값을 실행 중인 노드에 넣습니다. |
| `--ros-args --params-file ~/data.yaml` | 노드를 띄우면서 파일의 값을 처음부터 넣습니다. launch 파일이 파라미터를 넘기는 방법도 이것입니다. |

**관찰**:
- `ros2 param get` 은 `Double value is: 4.2` 처럼 타입과 함께 값을 보여 줍니다.
- `ros2 param list` 에는 직접 넣은 `my_dict.message`, `my_dict.x`, `my_param` 말고도 `use_sim_time`, `start_type_description_service`, `qos_overrides./parameter_events.publisher.*` 가 보입니다. 모든 노드가 기본으로 가지는 파라미터입니다.
- `data.yaml` 의 맨 위는 `/parameter_blackboard:` 그 아래는 `ros__parameters:` 입니다. 파라미터 파일은 "어느 노드의 파라미터인지"를 함께 적습니다.
- `ros2 param load` 를 하면 `my_dict.message` 와 `my_dict.x` 는 `successful` 로 바뀌고, `qos_overrides...` 와 `start_type_description_service` 는 `cannot be set because it is read-only` 로 실패합니다. 노드가 시작할 때만 정할 수 있는 읽기 전용 파라미터이기 때문입니다. 실패한 줄이 있어도 나머지 값은 들어갑니다.
- 마지막 `get` 은 두 번 다 `String value is: Goodbye world` 를 보여 줍니다.

**생각해 볼 질문**: 원서는 파라미터를 설정용으로만 쓰고 데이터를 주고받는 데 쓰지 말라고 합니다 (원서 PDF p.381). ROS 2에서 파라미터를 바꾸는 일이 실제로는 어떤 통신(토픽, 서비스, 액션 중 무엇)으로 이루어지는지 `ros2 node info /parameter_blackboard` 로 확인해 보세요.

### 실습 20-3. 패키지 위치 찾기와 실행 파일 실행

**준비**: 터미널 하나

**직접 입력**:

```bash
ros2 pkg prefix basics
ros2 pkg prefix --share basics
ros2 pkg prefix rclpy
ros2 pkg prefix no_such_pkg
ros2 pkg executables basics
source /usr/share/colcon_cd/function/colcon_cd.sh
export _colcon_cd_root=~/rosbook_ws
colcon_cd basics
pwd
cd ~
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `ros2 pkg prefix basics` | 패키지가 **설치된** 위치의 접두 경로(`~/rosbook_ws/install/basics`)를 보여 줍니다. |
| `--share` | 그 패키지의 `share` 폴더(launch 파일, `package.xml` 등이 설치되는 곳)를 보여 줍니다. |
| `ros2 pkg prefix rclpy` | apt로 설치한 패키지는 `/opt/ros/jazzy` 아래에 있습니다. |
| `no_such_pkg` | 없는 패키지는 `Package not found` 를 출력하고 실패 코드로 끝납니다. |
| `ros2 pkg executables basics` | `ros2 run` 으로 실행할 수 있는 실행 파일 목록입니다. |
| `source .../colcon_cd.sh` | `colcon_cd` 는 실행 파일이 아니라 셸 함수라서 이렇게 불러와야 쓸 수 있습니다. 원서의 `roscd` 가 rosbash 함수였던 것과 같은 이유입니다 (원서 PDF p.382). |
| `export _colcon_cd_root=~/rosbook_ws` | `colcon_cd` 가 소스를 찾을 워크스페이스를 알려 줍니다. |
| `colcon_cd basics` | `basics` 패키지의 **소스** 폴더로 이동합니다. |

**관찰**:
- 설치 위치와 소스 위치가 다릅니다. 코드를 고칠 곳은 소스(`src/basics`), 실행될 곳은 설치 폴더(`install/basics`)입니다. `--symlink-install` 로 빌드했기 때문에 Python 파일은 설치 폴더에서 소스 파일을 가리키는 링크로 들어가 있습니다.
- `colcon_cd basics` 뒤의 `pwd` 가 `~/rosbook_ws/src/basics` 를 보여 줍니다.

**생각해 볼 질문**: launch 파일을 새로 추가했는데 `ros2 launch` 가 찾지 못한다면, `ros2 pkg prefix --share basics` 가 알려 주는 폴더의 어디를 확인해야 할까요?

### 실습 20-4. ros2 run에서 이름 바꾸기

**준비**: 터미널 두 개

**직접 입력**:

터미널 1:

```bash
ros2 run basics topic_publisher --ros-args -r counter:=my_counter -r __node:=talker
```

터미널 2:

```bash
ros2 node list
ros2 topic list -t
ros2 run basics topic_subscriber --ros-args -r counter:=my_counter
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `--ros-args` | 여기부터는 ROS가 해석하는 인자라는 표시입니다. |
| `-r counter:=my_counter` | 코드 안의 토픽 이름 `counter` 를 실행할 때 `my_counter` 로 바꿉니다. 원서 launch 예제의 `<remap>` 과 같은 일입니다. |
| `-r __node:=talker` | 노드 이름을 `talker` 로 바꿉니다. 같은 실행 파일을 여러 개 띄울 때 이름이 겹치지 않게 합니다. |

**관찰**:
- `ros2 node list` 에 `/talker` 가, `ros2 topic list -t` 에 `/my_counter [std_msgs/msg/Int32]` 가 나옵니다.
- 구독자도 같은 재매핑을 해야 숫자를 받습니다. 재매핑 없이 띄우면 `/counter` 를 기다리며 아무것도 출력하지 않습니다.

**생각해 볼 질문**: 재매핑을 발행자에만 하고 구독자에는 하지 않았을 때, `ros2 topic list` 에는 토픽이 몇 개 보일까요?

### 실습 20-5. launch 파일 세 가지 형식

**준비**: 터미널 두 개

**직접 입력**: 폴더 `~/rosbook_ws/src/basics/launch/` 를 만들고 세 파일을 만듭니다. 세 파일은 같은 일을 합니다.

파일 `~/rosbook_ws/src/basics/launch/counter.launch.py`:

```python
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    topic = LaunchConfiguration('topic')
    return LaunchDescription([
        DeclareLaunchArgument('topic', default_value='counter'),
        Node(
            package='basics',
            executable='topic_publisher',
            name='talker',
            remappings=[('counter', topic)],
            parameters=[{'my_param': 4.2}],
        ),
        Node(
            package='basics',
            executable='topic_subscriber',
            name='listener',
            remappings=[('counter', topic)],
            output='screen',
        ),
    ])
```

파일 `~/rosbook_ws/src/basics/launch/counter.launch.xml`:

```xml
<launch>
  <arg name="topic" default="counter"/>
  <node pkg="basics" exec="topic_publisher" name="talker">
    <remap from="counter" to="$(var topic)"/>
    <param name="my_param" value="4.2"/>
  </node>
  <node pkg="basics" exec="topic_subscriber" name="listener" output="screen">
    <remap from="counter" to="$(var topic)"/>
  </node>
</launch>
```

파일 `~/rosbook_ws/src/basics/launch/counter.launch.yaml`:

```yaml
launch:
  - arg:
      name: topic
      default: counter
  - node:
      pkg: basics
      exec: topic_publisher
      name: talker
      remap:
        - from: counter
          to: $(var topic)
      param:
        - name: my_param
          value: 4.2
  - node:
      pkg: basics
      exec: topic_subscriber
      name: listener
      output: screen
      remap:
        - from: counter
          to: $(var topic)
```

launch 파일이 설치되도록 `~/rosbook_ws/src/basics/setup.py` 를 고칩니다. 맨 위 import 부분과 `data_files` 만 바꿉니다.

```python
from glob import glob
import os

from setuptools import find_packages, setup
```

```python
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*')),
    ],
```

`~/rosbook_ws/src/basics/package.xml` 의 `<depend>` 줄들 아래에 실행 의존성을 추가합니다.

```xml
  <exec_depend>launch_ros</exec_depend>
  <exec_depend>ros2launch</exec_depend>
```

빌드하고 실행합니다.

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics
source ~/rosbook_ws/install/setup.bash
ros2 launch basics counter.launch.py --show-args
ros2 launch basics counter.launch.py topic:=launch_counter
```

터미널 2:

```bash
ros2 node list
ros2 topic info -v /launch_counter
ros2 param get /talker my_param
ros2 param list /talker
```

터미널 1을 Ctrl+C로 멈추고 `counter.launch.xml`, `counter.launch.yaml` 로도 똑같이 해 봅니다.

**줄 단위 해설** (Python 형식 기준, 괄호 안은 XML/YAML에서의 표기):

| 줄 | 설명 |
|---|---|
| `generate_launch_description()` | `ros2 launch` 가 Python launch 파일에서 찾는 함수 이름입니다. 이 함수가 돌려준 목록대로 실행합니다. |
| `DeclareLaunchArgument('topic', default_value='counter')` (`<arg>`, `arg:`) | 명령줄에서 `topic:=...` 로 바꿀 수 있는 launch 인자(argument)를 선언합니다. |
| `LaunchConfiguration('topic')` (`$(var topic)`) | 인자의 값을 실행 시점에 꺼내 쓰는 자리 표시입니다. 파일을 읽을 때가 아니라 실행할 때 값이 정해집니다. |
| `Node(package=..., executable=..., name=...)` (`pkg`, `exec`, `name`) | 실행할 노드입니다. 원서 XML의 `type` 이 `exec` 로 바뀌었습니다. |
| `remappings=[('counter', topic)]` (`<remap>`) | 실습 20-4의 `-r counter:=...` 와 같습니다. |
| `parameters=[{'my_param': 4.2}]` (`<param>`) | 노드에 넘길 파라미터입니다. |
| `output='screen'` | 노드의 표준 출력도 화면에 보여 줍니다. |
| `glob('launch/*')` | `launch` 폴더의 파일을 모두 `share/basics/launch` 로 설치합니다. 이 줄이 없으면 `ros2 launch` 가 파일을 찾지 못합니다. |
| `from glob import glob` 다음 `import os` | import 순서는 테스트(flake8)가 검사합니다. 알파벳 순서상 `glob` 이 `os` 보다 앞이어야 실습 20-7의 테스트를 통과합니다. |

**관찰**:
- `--show-args` 는 `'topic': no description given (default: 'counter')` 처럼 받을 수 있는 인자를 보여 줍니다.
- 세 형식 모두 `ros2 node list` 에 `/listener`, `/talker` 가 나오고, `/launch_counter` 의 발행자는 `talker`, 구독자는 `listener` 로 나옵니다.
- 터미널 1에는 `[topic_subscriber-2] [INFO] ... [listener]: 0` 처럼 프로세스 이름이 앞에 붙은 로그가 찍힙니다.
- `ros2 param get /talker my_param` 은 `Parameter not set` 을 출력하고, `ros2 param list /talker` 에도 `my_param` 이 없습니다. launch가 값을 넘겼지만 `topic_publisher` 가 그 이름을 선언하지 않았기 때문에 무시된 것입니다. 원서에서는 같은 확인이 `4.2` 를 보여 주었습니다 (원서 PDF p.385). ROS 2에서 파라미터를 쓰려면 노드 코드에 `declare_parameter('my_param', 0.0)` 이 있어야 합니다.
- Ctrl+C로 멈출 때 Python 노드 쪽에 `KeyboardInterrupt` 트레이스백과 `process has died ... exit code -2` 가 찍힐 수 있습니다. 노드가 종료 처리 중에 중단 신호를 한 번 더 받아서 생기는 것으로 보이며, 다음 실행에는 영향이 없습니다.

**생각해 볼 질문**: 세 형식 중 조건문이나 반복문처럼 프로그래밍이 필요한 launch 설정에는 무엇이 가장 알맞을까요? 사람이 읽고 고치기 쉬운 것은 무엇일까요?

### 실습 20-6. launch 파일 나누고 포함하기

**준비**: 터미널 두 개

**직접 입력**: 파일 `~/rosbook_ws/src/basics/launch/listener.launch.xml`:

```xml
<launch>
  <arg name="topic" default="counter"/>
  <node pkg="basics" exec="topic_subscriber" name="listener" output="screen">
    <remap from="counter" to="$(var topic)"/>
  </node>
</launch>
```

파일 `~/rosbook_ws/src/basics/launch/counter_include.launch.py`:

```python
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import AnyLaunchDescriptionSource
from launch.substitutions import PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    listener_file = PathJoinSubstitution(
        [FindPackageShare('basics'), 'launch', 'listener.launch.xml'])
    return LaunchDescription([
        Node(
            package='basics',
            executable='topic_publisher',
            name='talker',
            remappings=[('counter', 'my_counter')],
        ),
        IncludeLaunchDescription(
            AnyLaunchDescriptionSource(listener_file),
            launch_arguments={'topic': 'my_counter'}.items(),
        ),
    ])
```

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics
source ~/rosbook_ws/install/setup.bash
ros2 launch basics counter_include.launch.py
```

터미널 2:

```bash
ros2 topic info /my_counter
ros2 launch basics counter_include.launch.py --print
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `FindPackageShare('basics')` | 설치된 `basics` 패키지의 share 폴더를 찾습니다. 원서의 `$(find basics)` 에 해당하며, XML에서는 `$(find-pkg-share basics)` 로 씁니다. |
| `PathJoinSubstitution([...])` | 경로 조각을 이어 붙입니다. 이것도 실행 시점에 계산됩니다. |
| `IncludeLaunchDescription(AnyLaunchDescriptionSource(...))` | 다른 launch 파일을 포함합니다. `AnyLaunchDescriptionSource` 는 Python, XML, YAML 형식을 가리지 않고 읽습니다. |
| `launch_arguments={'topic': 'my_counter'}.items()` | 포함하는 파일의 `topic` 인자에 값을 넘깁니다. |
| `--print` | 노드를 실행하지 않고 launch 파일이 만들어 내는 실행 계획을 나무 모양으로 보여 줍니다. |

**관찰**:
- `ros2 topic info /my_counter` 가 `Publisher count: 1`, `Subscription count: 1` 을 보여 줍니다. Python 파일이 XML 파일을 포함해도 잘 이어집니다.
- `--print` 출력에는 `DeclareLaunchArgument`, `ExecuteProcess(...)` 같은 항목이 보입니다. launch 파일은 "실행할 일의 목록"을 만드는 프로그램이라는 것을 보여 줍니다.

**생각해 볼 질문**: `launch_arguments` 줄을 지우면 포함된 listener는 어느 토픽을 구독할까요?

### 실습 20-7. launch_testing으로 여러 노드 시험하기

**준비**: 터미널 하나

**직접 입력**: 파일 `~/rosbook_ws/src/basics/test/test_counter_launch.py`:

```python
import time
import unittest

from launch import LaunchDescription
from launch_ros.actions import Node
import launch_testing.actions
import launch_testing.asserts
import pytest
import rclpy
from std_msgs.msg import Int32


@pytest.mark.launch_test
def generate_test_description():
    talker = Node(package='basics', executable='topic_publisher', name='talker')
    return LaunchDescription([
        talker,
        launch_testing.actions.ReadyToTest(),
    ])


class TestCounter(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        rclpy.init()

    @classmethod
    def tearDownClass(cls):
        rclpy.shutdown()

    def setUp(self):
        self.node = rclpy.create_node('test_counter')

    def tearDown(self):
        self.node.destroy_node()

    def test_counter_increases(self):
        received = []
        self.node.create_subscription(
            Int32, 'counter', lambda msg: received.append(msg.data), 10)
        deadline = time.time() + 10.0
        while time.time() < deadline and len(received) < 3:
            rclpy.spin_once(self.node, timeout_sec=0.1)
        self.assertGreaterEqual(len(received), 3, 'no counter messages within 10 s')
        self.assertEqual(received[1], received[0] + 1)
        self.assertEqual(received[2], received[1] + 1)


@launch_testing.post_shutdown_test()
class TestShutdown(unittest.TestCase):

    def test_exit_code(self, proc_info):
        launch_testing.asserts.assertExitCodes(proc_info)
```

`~/rosbook_ws/src/basics/package.xml` 의 `<test_depend>` 줄들 아래에 추가합니다.

```xml
  <test_depend>launch_testing</test_depend>
  <test_depend>launch_testing_ros</test_depend>
```

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics
source ~/rosbook_ws/install/setup.bash
launch_test ~/rosbook_ws/src/basics/test/test_counter_launch.py
colcon test --packages-select basics
colcon test-result --verbose
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `@pytest.mark.launch_test` | pytest에게 "이 파일은 launch 테스트"라고 알립니다. 이 표시가 있어야 `colcon test` 가 노드를 띄운 뒤 테스트를 돌립니다. |
| `generate_test_description()` | 테스트 동안 띄울 노드 목록입니다. 원서 rostest 파일의 `<node>` 태그에 해당합니다. |
| `ReadyToTest()` | 노드를 띄웠으니 이제 테스트를 시작해도 된다는 신호입니다. |
| `class TestCounter(unittest.TestCase)` | 노드가 떠 있는 동안 실행되는 테스트 묶음입니다. 원서의 `test_talker.py` 에 해당합니다. |
| `setUpClass` / `tearDownClass` | 테스트 묶음 전체에서 rclpy를 한 번 초기화하고 한 번 정리합니다. |
| `setUp` / `tearDown` | 테스트 함수마다 검사용 노드를 새로 만들고 지웁니다. |
| `create_subscription(..., lambda msg: received.append(msg.data), 10)` | 받은 숫자를 목록에 모읍니다. |
| `while ... spin_once(..., timeout_sec=0.1)` | 최대 10초 동안 콜백을 처리하며 세 개를 모을 때까지 기다립니다. 원서 테스트의 10초 제한과 같은 생각입니다. |
| `assertGreaterEqual`, `assertEqual` | 메시지가 세 개 이상 왔는지, 숫자가 1씩 늘어나는지 확인합니다. 원서보다 한 단계 더 검사합니다. |
| `@launch_testing.post_shutdown_test()` | 노드가 모두 끝난 뒤에 실행되는 테스트입니다. |
| `assertExitCodes(proc_info)` | 띄운 노드가 정상 종료 코드로 끝났는지 확인합니다. |
| `launch_test 파일` | 이 파일 하나만 바로 실행합니다. |
| `colcon test` / `colcon test-result --verbose` | 패키지의 모든 테스트(코드 스타일 검사 포함)를 돌리고 결과를 요약합니다. |

**관찰**:
- `launch_test` 는 `test_counter_increases ... ok`, 이어서 `sending signal 'SIGINT' to process[topic_publisher-1]`, `process has finished cleanly`, `test_exit_code ... ok` 를 출력합니다.
- `colcon test-result` 는 `basics` 에서 `4 tests, 0 errors, 0 failures, 1 skipped` 처럼 요약합니다. launch 테스트 하나와 패키지 생성 때 함께 생긴 스타일 검사 테스트들(flake8, pep257, copyright)이 함께 세어지고, copyright 검사는 건너뜁니다.
- 실패하면 `colcon test-result --verbose` 가 실패한 테스트 이름과 메시지를 보여 줍니다.

**생각해 볼 질문**: 원서는 rostest가 `<test>` 태그마다 노드를 다시 띄운다고 설명합니다 (원서 PDF p.387). 이 파일에서 `TestCounter` 안에 테스트 함수를 하나 더 추가하면, 그 함수가 실행될 때 `topic_publisher` 는 다시 시작될까요?

### 실습 20-8. 처음 보는 시스템 들여다보기

**준비**: 터미널 두 개. 원서처럼 "구조를 모르는 시스템"을 바깥에서 알아내는 연습입니다.

**직접 입력**:

터미널 1:

```bash
ros2 run basics topic_subscriber
```

터미널 2:

```bash
ros2 node list
ros2 node info /topic_subscriber
ros2 topic list -t
ros2 topic info -v /counter
ros2 interface show std_msgs/msg/Int32
ros2 topic pub --once /counter std_msgs/msg/Int32 "{data: 1000000}"
ros2 interface show basics_interfaces/srv/WordCount
ros2 service list -t
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `ros2 node info /topic_subscriber` | 이 노드의 구독, 발행, 서비스 서버, 서비스 클라이언트, 액션 목록을 보여 줍니다. |
| `ros2 topic list -t` | 토픽 이름과 타입을 함께 봅니다. |
| `ros2 topic info -v /counter` | 발행자와 구독자 노드, 그리고 각 연결의 QoS(Quality of Service: 신뢰성, 보관 개수 같은 전달 정책)를 보여 줍니다. |
| `ros2 interface show` | 메시지, 서비스, 액션 정의를 보여 줍니다. 원서의 `rosmsg show`, `rossrv show` 를 합친 것입니다. |
| `ros2 topic pub --once` | 메시지 하나를 발행하고 끝납니다. 값은 YAML로 씁니다. `--once` 가 없으면 1초마다 계속 발행합니다. |
| `ros2 service list -t` | 서비스 이름과 타입을 함께 봅니다. |

**관찰**:
- `ros2 node info` 의 `Subscribers:` 에 `/counter: std_msgs/msg/Int32` 가 있고, `Publishers:` 에는 모든 노드가 기본으로 가지는 `/parameter_events`, `/rosout` 이 있습니다. `Service Servers:` 의 `/topic_subscriber/get_parameters` 같은 서비스가 실습 20-2의 `ros2 param` 명령이 쓰는 통로입니다.
- `ros2 topic info -v` 에서 구독자의 QoS가 `Reliability: RELIABLE`, `History (Depth): KEEP_LAST (10)`, `Durability: VOLATILE` 로 보입니다. 코드의 `create_subscription(..., 10)` 의 10이 여기 나타난 것입니다.
- `ros2 interface show std_msgs/msg/Int32` 는 `int32 data` 와 함께, 이 타입이 오래된 것이니 의미가 분명한 메시지를 쓰라는 주석을 보여 줍니다.
- 터미널 1에 `[INFO] [...] [topic_subscriber]: 1000000` 이 찍힙니다.
- `ros2 service list -t` 에는 지금 떠 있는 노드의 파라미터 서비스들만 보입니다. `WordCount` 정의는 보이지만 그 서비스를 제공하는 노드가 없으므로 `/word_count` 는 목록에 없습니다. 정의(interface)와 실제 서비스는 다릅니다.

**생각해 볼 질문**: 원서는 `rosnode ping` 으로 노드가 응답하는지 확인합니다 (원서 PDF p.392). 이 명령이 없는 ROS 2에서 노드가 살아 있고 일하는지 확인하려면 위의 명령 중 무엇을 쓰면 될까요?

## 4. 일부러 망가뜨려 보기

| 바꿀 것 | 예상 증상 | 원인을 확인하는 명령 |
|---|---|---|
| `ros2 run basics topic_publisher --ros-args -p my_param:=4.2` 로 실행한 뒤 값을 확인 | `ros2 param get /topic_publisher my_param` 이 `Parameter not set`, `ros2 param set ... my_param 1.0` 은 `Setting parameter failed: Invalid access to undeclared parameter(s)` 로 실패합니다. 노드 터미널에도 `Failed to get parameters` 경고가 남습니다. | `ros2 param list /topic_publisher` 로 선언된 이름 확인 |
| `parameter_blackboard` 에서 double로 넣은 `my_param` 에 `hello` 를 다시 set | 이 노드는 타입이 바뀌는 것을 허용해서 `Set parameter successful` 후 `String value is: hello` 가 됩니다. 19장의 `speaker` 노드처럼 타입을 정해 선언한 노드는 같은 일을 거부합니다. | `ros2 param describe /parameter_blackboard my_param` |
| `setup.py` 의 `data_files` 에서 launch 줄을 빼고 빌드 | `ros2 launch basics counter.launch.py` 가 파일을 찾지 못한다는 오류로 끝납니다. | `ls $(ros2 pkg prefix --share basics)/launch` |
| launch 파일 실행 중 터미널 2에서 `ros2 topic list` 했는데 `/launch_counter` 대신 `/counter` 가 보임 | `topic:=launch_counter` 를 빠뜨렸거나 `:=` 대신 `=` 를 썼습니다. | `ros2 launch basics counter.launch.py --show-args` |
| 실습 20-7의 테스트 파일에서 토픽 이름을 `countr` 로 오타 | `test_counter_increases` 가 10초 뒤 `no counter messages within 10 s` 로 실패합니다. | `colcon test-result --verbose` |
| `setup.py` 에서 `import os` 를 `from glob import glob` 보다 위로 | `colcon test` 에서 flake8 테스트가 import 순서 오류(I100)로 실패합니다. 빌드와 실행은 잘 됩니다. | `colcon test-result --verbose` |
| `ros2 daemon stop` 만 하고 start를 잊음 | 이 가이드의 환경에서는 다음 `ros2 node list` 등이 출력 없이 멈출 수 있습니다. | Ctrl+C로 멈춘 뒤 `ros2 daemon start` 하고 다시 시도 |

## 5. 확인 질문

<details><summary>Q1. 실습 20-1의 질문: ROS 2에서 daemon이 죽으면 새 노드끼리의 통신은 어떻게 되나요?</summary>

아무 영향이 없습니다. 노드는 daemon에 등록하지 않고 DDS discovery로 서로를 직접 찾기 때문입니다. daemon이 없을 때 느려지거나 멈추는 것은 `ros2` 명령줄 도구뿐이고, `ros2 daemon start` 로 다시 띄우면 됩니다. 원서의 master가 시스템 전체의 단일 장애점이었던 것과 다른 점입니다.

</details>

<details><summary>Q2. 실습 20-2의 질문: 파라미터를 바꾸는 일은 어떤 통신으로 이루어지나요?</summary>

서비스입니다. `ros2 node info` 의 `Service Servers:` 에 `<노드>/get_parameters`, `<노드>/set_parameters`, `<노드>/list_parameters`, `<노드>/describe_parameters` 등이 있고, `ros2 param` 명령은 이 서비스들을 호출합니다. 값이 바뀌었다는 알림은 `/parameter_events` 토픽으로 나갑니다.

</details>

<details><summary>Q3. 실습 20-3의 질문: 새 launch 파일을 `ros2 launch` 가 찾지 못하면 어디를 확인하나요?</summary>

`$(ros2 pkg prefix --share basics)/launch` 폴더에 그 파일이 설치되었는지 확인합니다. 없다면 `setup.py` 의 `data_files` 에 launch 줄이 없거나, 파일을 추가한 뒤 다시 빌드하지 않은 것입니다. `--symlink-install` 은 이미 설치된 파일의 내용 변경만 바로 반영하고, 새 파일은 다시 빌드해야 설치됩니다.

</details>

<details><summary>Q4. 실습 20-4의 질문: 발행자만 재매핑하면 토픽이 몇 개 보이나요?</summary>

`/my_counter` (발행자만 있음)와 `/counter` (구독자만 있음) 두 개가 보입니다. `ros2 topic info` 로 각각의 `Publisher count`, `Subscription count` 를 보면 한쪽이 0인 것으로 연결이 끊어진 것을 알 수 있습니다.

</details>

<details><summary>Q5. 실습 20-5의 질문: 세 형식은 각각 언제 알맞나요?</summary>

조건, 반복, 계산이 필요하면 Python 형식이 알맞습니다. 노드 목록과 설정을 적어 두기만 하면 되는 경우에는 XML이나 YAML이 짧고 읽기 쉽습니다. 실습 20-6처럼 Python 파일이 XML 파일을 포함할 수도 있으므로, 복잡한 부분만 Python으로 쓰고 나머지는 XML로 두는 방법도 있습니다.

</details>

<details><summary>Q6. 실습 20-6의 질문: `launch_arguments` 를 지우면 listener는 어느 토픽을 구독하나요?</summary>

포함된 파일의 `topic` 인자 기본값인 `counter` 를 구독합니다. 발행자는 `my_counter` 로 보내므로 두 노드가 연결되지 않습니다.

</details>

<details><summary>Q7. 실습 20-7의 질문: 테스트 함수를 하나 더 추가하면 노드가 다시 시작되나요?</summary>

다시 시작되지 않습니다. `generate_test_description()` 이 띄운 노드는 같은 파일 안의 모든 테스트 함수가 끝날 때까지 계속 떠 있습니다. 그래서 두 번째 테스트 함수가 받는 첫 숫자는 0이 아닐 수 있습니다. 이 장의 테스트가 "0부터 시작한다"가 아니라 "1씩 늘어난다"를 검사하는 이유입니다.

</details>

<details><summary>Q8. 실습 20-8의 질문: `rosnode ping` 대신 무엇으로 노드가 살아 있는지 확인하나요?</summary>

`ros2 node list` 로 노드가 그래프에 있는지 확인하고, 발행자라면 `ros2 topic echo` 나 `ros2 topic hz` 로 실제로 메시지가 나오는지 봅니다. 파라미터 서비스에 응답하는지 보려면 `ros2 param list /노드` 를 입력해 볼 수도 있습니다.

</details>

## 6. 원서 대조 메모

- 원서의 roscore 설명(master, 파라미터 서버, rosout 노드 세 가지, 원서 PDF p.379~380)은 ROS 2에 그대로 대응하는 것이 없습니다. rosout은 ROS 2에서도 `/rosout` 토픽으로 남아 있으며 21장에서 다룹니다.
- 원서의 `rosparam` 예제는 전역 파라미터 서버를 전제로 합니다 (원서 PDF p.381~382). 이 장은 아무 이름이나 받는 `demo_nodes_cpp` 의 `parameter_blackboard` 노드로 같은 흐름을 따라 했습니다. 원서의 `rosparam dump data.yaml my_dict` 처럼 일부만 덤프하는 기능은 `ros2 param dump` 에 없고, 노드 전체를 덤프합니다.
- 원서 p.385의 launch 파라미터 확인(`talker/my_param` 이 4.2)은 ROS 2에서 같은 결과가 나오지 않습니다. 노드가 선언하지 않은 파라미터는 무시되기 때문입니다(실습 20-5).
- 원서의 rostest 예제는 `self.assert_()` 를 씁니다 (원서 PDF p.387). 이 메서드는 Python 3.12에서 제거되어 Ubuntu 24.04에서는 쓸 수 없습니다. 또 launch 파일의 `test-name="test_talker"` 와 `rostest.rosrun` 의 `'talker_test'` 가 서로 다른 이름입니다.
- 원서 p.391의 `\logger services` 는 `/logger services` 의 오타로 보입니다.
- 원서 p.390의 `rostopic pub` 설명처럼 ROS 2의 `ros2 topic pub` 도 YAML로 값을 받습니다. 다만 ROS 2는 기본이 한 번 발행 후 대기(latch)가 아니라 1초마다 반복 발행이며, 한 번만 보내려면 `--once` 를 씁니다.

## 7. 이 문서의 검증 상태

- 확인함 (2026-10-27, 검증용 별도 워크스페이스, `ROS_DOMAIN_ID` 분리, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`, daemon 미리 실행 또는 `--no-daemon --spin-time 3`):
  - `ros2 daemon start` 출력, `--no-daemon --spin-time` 으로 노드 찾기.
  - 실습 20-2의 모든 명령과 출력: set/get/describe/list/delete/dump 내용, load 때 읽기 전용 파라미터 실패 메시지, `--params-file` 로 재시작 후 값.
  - `ros2 pkg prefix`(설치 경로, `--share`, `/opt/ros/jazzy`, 없는 패키지의 `Package not found`), `/usr/share/colcon_cd/function/colcon_cd.sh` 파일 존재.
  - `-r counter:=my_counter -r __node:=talker` 결과.
  - 세 형식 launch 파일 각각의 노드 목록, 토픽 정보, `my_param` 이 `Parameter not set` 인 것, `--show-args`, `--print`, include 결과, 종료 때 `KeyboardInterrupt` 트레이스백과 exit code -2.
  - 4절의 선언하지 않은 파라미터 get/set 메시지와 노드 경고, `parameter_blackboard` 의 타입 변경 허용, flake8 import 순서 실패(I100).
  - `launch_test` 단독 실행 출력, `colcon test` 결과(`basics`: 4 tests, 0 failures, 1 skipped).
  - `ros2 node info`, `ros2 topic info -v` 의 QoS, `ros2 topic pub --once` 수신, `ros2 interface show`.
  - `ros2 node` 하위 명령이 `info`, `list` 뿐인 것, `ros2 param` 하위 명령 목록, `ros2 launch` 의 `--show-args`/`--print`/`--debug`/`--launch-prefix`, `ros2 run --prefix`.
- 확인 못 함:
  - `colcon_cd basics` 를 실제로 실행해 이동하는 것(함수 파일만 확인했습니다).
  - daemon을 껐다 켠 직후 `ros2 node list` 가 비어 있다가 채워지는 시간. 검증 환경에서는 `ros2 daemon stop` 자체가 20초 시간 제한에 걸린 적이 있었습니다. README에 적은 측정에서 daemon이 이미 꺼져 있을 때는 `ros2 daemon stop`도 약 2분 17초 멈췄으므로, 이 경우였을 가능성이 큽니다.
  - Ctrl+C로 launch를 멈출 때의 `KeyboardInterrupt` 트레이스백이 생기는 정확한 원인. 검증에서는 launch 프로세스에 SIGINT를 보내 재현했고, 학습자의 터미널 Ctrl+C와 완전히 같은 조건은 아닙니다.
  - `launch_arguments` 를 지웠을 때(Q6), `data_files` 를 뺐을 때, 테스트 토픽 오타의 실제 출력 문구.
  - Fast DDS에서의 동작. 이 가이드는 README의 안내대로 Cyclone DDS를 전제로 합니다.
