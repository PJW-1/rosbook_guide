# 8장. Teleop-bot

- 원서: Chapter 8. Teleop-bot, PDF p.131~154 (인쇄 쪽 = PDF 쪽 - 20)
- 선행 조건: 7장을 마쳐 `TwistStamped` 발행과 `setup.py` 등록에 익숙합니다. 6장의 시뮬 실행 방법을 알고 있습니다.
- 새로 설치할 것: 없음 (`ros-jazzy-teleop-twist-keyboard` 2.4.1, `ros-jazzy-rqt-plot`, `ros-jazzy-rviz2`가 이미 설치되어 있습니다)

## 이 장에서 체감할 구조
키 입력을 읽는 노드와 키를 속도로 바꾸는 노드를 나누고, 둘을 `/keys` 토픽으로 잇습니다. 한쪽을 바꿔도 다른 쪽은 그대로 씁니다.
속도 배율과 가속도 같은 "조정값"은 코드가 아니라 파라미터로 빼서, 실행 중에 `ros2 param`으로 보고 바꿉니다.

```
 터미널 키보드 ─▶ [keyboard_driver] ─▶ /keys (String) ─▶ [keys_to_twist] ─▶ /cmd_vel (TwistStamped) ─▶ 브리지 ─▶ Gazebo
                                                         ▲ 파라미터: linear_scale, angular_scale, linear_accel, angular_accel
```

## 1. 목표와 개념
원서 8장은 키보드로 로봇을 조종하는 프로그램을 작은 단계로 키워 갑니다(개발 방식 설명 PDF p.132). 키를 토픽으로 내보내는 노드(PDF p.133), 키를 속도로 바꾸는 노드(PDF p.134~137), 파라미터로 배율 조정(PDF p.139~141), 가감속 제한(ramp, PDF p.142~144), 시뮬에서 직접 몰아 보기(PDF p.145~146), rviz로 센서와 좌표계 보기(PDF p.146~154)입니다.

- **역할 분리**: 키보드 입력은 터미널이라는 특수한 자원에 묶여 있습니다. 그 부분만 작은 노드로 떼어 두면, 속도 변환 노드는 `ros2 topic pub`으로 가짜 키를 넣어 시험할 수 있습니다.
- **이벤트 발행과 주기 발행**: 키가 눌릴 때만 내는 방식은 단순하지만, 받는 쪽이 "마지막 명령이 언제였는지" 알 수 없습니다. 주기적으로 마지막 명령을 다시 보내면 받는 쪽이 끊김을 감지할 수 있습니다.
- **파라미터**: ROS 2 파라미터는 노드마다 따로 있고, 노드가 `declare_parameter`로 이름과 기본값(그리고 타입)을 선언해야 존재합니다. 실행할 때 `--ros-args -p 이름:=값` 또는 `--params-file 파일.yaml`로 바꾸고, 실행 중에는 `ros2 param get/set`으로 다룹니다.
- **ramp(가감속 제한)**: 목표 속도로 한 번에 뛰지 않고 주기마다 "가속도 × 시간"만큼만 다가가게 합니다. 실제 모터와 바퀴가 미끄러지지 않게 하는 흔한 방법입니다.
- **rviz2**: 토픽의 데이터를 3D로 그려 보는 도구입니다. 무엇을 기준 좌표계(Fixed Frame)로 그릴지 정하고, 토픽마다 Display를 추가합니다.

비유: 파라미터는 노드에 달린 조절 다이얼입니다. 다이얼 이름과 눈금 단위(타입)는 노드가 정하고, 바깥에서는 돌리기만 합니다.

## 2. 원서(ROS 1)와 달라지는 점
| 원서 (ROS 1) | ROS 2 Jazzy | 이유와 주의점 |
|---|---|---|
| `tty.setraw` + `select`를 `while` 루프로 반복 | `tty.setcbreak` + 0.01초 타이머 안에서 `select` | cbreak 모드는 한 글자씩 읽으면서 Ctrl-C를 신호로 남겨 두므로 노드를 정상 종료할 수 있습니다. |
| `geometry_msgs/Twist` | `geometry_msgs/msg/TwistStamped` | 시뮬 브리지가 TwistStamped를 받습니다. |
| 파라미터 서버의 전역 값, `rospy.get_param('~linear_scale', 0.1)` | 노드가 `declare_parameter('linear_scale', 0.1)`로 선언 | 선언하지 않은 파라미터는 `ros2 param set`으로 만들 수 없습니다. 기본값의 타입(여기서는 실수)이 고정됩니다. |
| `rosrun ... _linear_scale:=0.5` | `ros2 run ... --ros-args -p linear_scale:=0.5` | 밑줄 접두사 문법이 없습니다. |
| `rosparam set` | `ros2 param set /노드 이름 값` | 노드 이름이 필요합니다. |
| `rospy.Time.now()`로 dt 계산 | `self.get_clock().now()`의 차이를 `nanoseconds`로 | `use_sim_time`을 따릅니다. |
| rviz (PDF p.146~) | rviz2 | 기본 Fixed Frame이 `map`인데 이 시뮬에는 `map`이 없습니다. `odom`으로 바꿔야 합니다. |
| `turtlebot_teleop` | `teleop_twist_keyboard` (`stamped` 파라미터) | 실습 8-9에서 비교합니다. |

## 3. 실습

### 실습 8-1. teleop_bot 패키지와 key_publisher
**준비**: 터미널 2개.

**직접 입력**:
```bash
cd ~/rosbook_ws/src
ros2 pkg create --build-type ament_python --license Apache-2.0 \
  --dependencies rclpy geometry_msgs std_msgs -- teleop_bot
```

`~/rosbook_ws/src/teleop_bot/teleop_bot/key_publisher.py`
```python
import os
import select
import sys
import termios
import tty

import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import String


class KeyPublisher(Node):
    def __init__(self):
        super().__init__('keyboard_driver')
        self.key_pub = self.create_publisher(String, 'keys', 10)
        self.fd = sys.stdin.fileno()
        self.timer = self.create_timer(0.01, self.check_key)
        self.get_logger().info('Publishing keystrokes. Press Ctrl-C to exit...')

    def check_key(self):
        ready, _, _ = select.select([self.fd], [], [], 0)
        if ready:
            msg = String()
            msg.data = os.read(self.fd, 1).decode(errors='replace')
            self.key_pub.publish(msg)


def main(args=None):
    rclpy.init(args=args)
    old_attr = termios.tcgetattr(sys.stdin)
    tty.setcbreak(sys.stdin.fileno())
    node = KeyPublisher()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_attr)
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
```

**줄 단위 해설**:
| 줄 | 설명 |
|---|---|
| 1~5 | 표준 입력을 다루는 모듈들입니다. `termios`와 `tty`는 터미널 모드를, `select`는 "읽을 것이 있는지"를 기다리지 않고 확인합니다. |
| 15 | 노드 이름은 원서와 대응되도록 `keyboard_driver`로 둡니다. 실행 파일 이름(`key_publisher`)과 노드 이름이 달라도 됩니다. |
| 16 | `keys` 토픽에 `std_msgs/msg/String`을 냅니다. 키는 놓치면 안 되므로 큐 깊이를 10으로 둡니다. |
| 17 | 표준 입력의 파일 번호를 기억해 둡니다. |
| 18 | 0.01초마다 키를 확인합니다. 루프 대신 타이머를 쓰므로 `rclpy.spin`이 계속 다른 일도 처리할 수 있습니다. |
| 22 | 제한 시간 0으로 `select`를 불러, 키가 없으면 바로 돌아옵니다. 타이머 콜백 안에서 멈춰 기다리면 안 되기 때문입니다. |
| 23~26 | 읽을 것이 있으면 1바이트를 읽어 문자열로 바꾸고 발행합니다. |
| 31~32 | 원래 터미널 설정을 저장하고 cbreak 모드로 바꿉니다. 이 모드에서는 Enter 없이 한 글자씩 들어오고, 입력한 글자가 화면에 다시 찍히지 않습니다. |
| 38~39 | 어떤 식으로 끝나든 터미널 설정을 되돌립니다. 이 줄이 없으면 노드가 끝난 뒤 터미널에 입력이 보이지 않게 됩니다. |

`~/rosbook_ws/src/teleop_bot/setup.py`의 `entry_points`를 이 장의 네 노드로 채웁니다.
```python
    entry_points={
        'console_scripts': [
            'key_publisher = teleop_bot.key_publisher:main',
            'keys_to_twist = teleop_bot.keys_to_twist:main',
            'keys_to_twist_parameterized = teleop_bot.keys_to_twist_parameterized:main',
            'keys_to_twist_with_ramps = teleop_bot.keys_to_twist_with_ramps:main',
        ],
    },
```

빌드하고 실행합니다(터미널 1).
```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select teleop_bot
source ~/rosbook_ws/install/setup.bash
ros2 run teleop_bot key_publisher
```
터미널 2:
```bash
ros2 topic echo /keys
```
터미널 1을 클릭해 초점을 준 뒤 `w`, `a`, `d`, 위쪽 화살표를 차례로 눌러 봅니다. 끝나면 Ctrl-C.

**관찰**:
- 터미널 2에 `data: w`, `data: a`, `data: d`가 하나씩 나옵니다.
- 위쪽 화살표는 한 번 눌렀는데 메시지가 세 개(`"\e"`, `[`, `A`) 나옵니다. 화살표 키는 터미널에서 세 글자짜리 제어 문자열로 들어오기 때문입니다.
- Ctrl-C 뒤에 터미널 1에서 입력한 글자가 다시 정상으로 보입니다.

**생각해 볼 질문**: 이 노드를 `ros2 launch` 파일에 넣거나 `< /dev/null`로 실행하면 어떻게 될까요? (Q1)

### 실습 8-2. keys_to_twist: 키를 속도로
**준비**: 실습 8-1의 패키지.

**직접 입력**: `~/rosbook_ws/src/teleop_bot/teleop_bot/keys_to_twist.py`
```python
from geometry_msgs.msg import TwistStamped
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import String

# key: (angular.z, linear.x)
KEY_MAPPING = {
    'w': (0.0, 1.0),
    'x': (0.0, -1.0),
    'a': (1.0, 0.0),
    'd': (-1.0, 0.0),
    's': (0.0, 0.0),
}


class KeysToTwist(Node):
    def __init__(self):
        super().__init__('keys_to_twist')
        self.twist_pub = self.create_publisher(TwistStamped, 'cmd_vel', 1)
        self.keys_sub = self.create_subscription(String, 'keys', self.keys_callback, 10)

    def keys_callback(self, msg):
        if len(msg.data) == 0 or msg.data[0] not in KEY_MAPPING:
            return
        angular, linear = KEY_MAPPING[msg.data[0]]
        twist = TwistStamped()
        twist.header.stamp = self.get_clock().now().to_msg()
        twist.twist.angular.z = angular
        twist.twist.linear.x = linear
        self.twist_pub.publish(twist)


def main(args=None):
    rclpy.init(args=args)
    node = KeysToTwist()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
```

**줄 단위 해설**:
| 줄 | 설명 |
|---|---|
| 7~14 | 키와 (회전 속도, 직진 속도)의 대응표입니다. `w` 전진, `x` 후진, `a` 왼쪽(반시계, +z) 회전, `d` 오른쪽 회전, `s` 정지입니다. ROS 좌표계에서 z축 양의 회전은 위에서 볼 때 반시계입니다. |
| 20 | `cmd_vel`에 TwistStamped를 냅니다. |
| 21 | `keys`를 구독합니다. 키가 들어올 때마다 `keys_callback`이 불립니다. |
| 24~25 | 빈 문자열이거나 표에 없는 키는 무시합니다. |
| 26~31 | 표에서 값을 꺼내 메시지를 채우고 바로 발행합니다. 이 노드에는 타이머가 없으므로 키가 와야만 발행합니다. |

빌드 후 시뮬 없이 시험합니다. 터미널 1:
```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select teleop_bot
ros2 run teleop_bot keys_to_twist
```
터미널 2:
```bash
ros2 topic echo /cmd_vel --field twist
```
터미널 3:
```bash
ros2 topic hz /cmd_vel
```
(몇 초 지켜본 뒤 Ctrl-C)
```bash
ros2 topic pub --once /keys std_msgs/msg/String "{data: w}"
ros2 topic pub --once /keys std_msgs/msg/String "{data: a}"
ros2 topic pub --once /keys std_msgs/msg/String "{data: q}"
```

**관찰**:
- 키를 넣기 전에는 `topic hz`가 아무 값도 내지 않습니다.
- `w`를 넣으면 echo에 `linear.x: 1.0`, `a`를 넣으면 `angular.z: 1.0`이 하나씩 나옵니다. `q`는 아무 출력도 만들지 않습니다.
- 여기서 `/keys`를 실습 8-1의 키보드 노드 대신 `ros2 topic pub`이 채웠다는 점이 역할 분리의 효과입니다.

시뮬에서 몰아 보려면 시뮬을 띄우고 `keys_to_twist`를 `--ros-args -p use_sim_time:=true`로, 다른 터미널에서 `key_publisher`를 실행합니다. 이 노드는 1 m/s를 그대로 보내므로 로봇이 매우 빠르게 움직입니다. `s`로 멈춥니다. 다음 실습에서 배율을 파라미터로 줄입니다.

원서처럼 값의 변화를 그래프로 보려면 다음을 실행합니다.
```bash
ros2 run rqt_plot rqt_plot /cmd_vel/twist/linear/x /cmd_vel/twist/angular/z
```

**생각해 볼 질문**: 키를 한 번 눌렀을 때 로봇은 언제까지 움직일까요? 이 방식이 위험한 이유는 무엇일까요? (Q2)

### 실습 8-3. 파라미터로 배율 조절하고 주기 발행으로 바꾸기
**준비**: 실습 8-2까지 빌드된 상태.

**직접 입력**: `~/rosbook_ws/src/teleop_bot/teleop_bot/keys_to_twist_parameterized.py`
```python
from geometry_msgs.msg import TwistStamped
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import String

# key: (angular.z, linear.x)
KEY_MAPPING = {
    'w': (0.0, 1.0),
    'x': (0.0, -1.0),
    'a': (1.0, 0.0),
    'd': (-1.0, 0.0),
    's': (0.0, 0.0),
}


class KeysToTwistParameterized(Node):
    def __init__(self):
        super().__init__('keys_to_twist')
        self.declare_parameter('linear_scale', 0.1)
        self.declare_parameter('angular_scale', 0.1)
        self.twist_pub = self.create_publisher(TwistStamped, 'cmd_vel', 1)
        self.keys_sub = self.create_subscription(String, 'keys', self.keys_callback, 10)
        self.last_twist = TwistStamped()
        self.timer = self.create_timer(0.1, self.send_twist)

    def keys_callback(self, msg):
        if len(msg.data) == 0 or msg.data[0] not in KEY_MAPPING:
            return
        angular, linear = KEY_MAPPING[msg.data[0]]
        linear_scale = self.get_parameter('linear_scale').value
        angular_scale = self.get_parameter('angular_scale').value
        self.last_twist.twist.angular.z = angular * angular_scale
        self.last_twist.twist.linear.x = linear * linear_scale

    def send_twist(self):
        self.last_twist.header.stamp = self.get_clock().now().to_msg()
        self.twist_pub.publish(self.last_twist)


def main(args=None):
    rclpy.init(args=args)
    node = KeysToTwistParameterized()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
```

**줄 단위 해설**:
| 줄 | 설명 |
|---|---|
| 19 | 노드 이름을 실습 8-2와 같은 `keys_to_twist`로 둡니다. 그래서 다음 실습의 yaml 하나를 세 노드 모두에 쓸 수 있습니다. 대신 두 노드를 동시에 띄우면 이름이 겹치므로 하나씩만 실행합니다. |
| 20~21 | 두 파라미터를 선언하고 기본값 0.1을 줍니다. 기본값이 실수이므로 이 파라미터의 타입은 double로 고정됩니다. |
| 24 | 마지막 명령을 보관할 메시지입니다. 처음에는 모두 0(정지)입니다. |
| 25 | 0.1초마다 마지막 명령을 다시 보냅니다. 이제 `/cmd_vel`이 10 Hz로 꾸준히 나옵니다. |
| 31~32 | 파라미터 값을 키가 올 때마다 다시 읽습니다. 그래서 실행 중에 `ros2 param set`으로 바꾼 값이 다음 키부터 바로 반영됩니다. |
| 33~34 | 표의 값에 배율을 곱해 보관만 합니다. 실제 발행은 타이머가 합니다. |
| 36~38 | 보낼 때마다 stamp를 새로 찍고 발행합니다. |

빌드하고 실행합니다(터미널 1).
```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select teleop_bot
ros2 run teleop_bot keys_to_twist_parameterized
```
터미널 2에서 파라미터를 살펴봅니다.
```bash
ros2 param list /keys_to_twist
ros2 param get /keys_to_twist linear_scale
ros2 topic hz /cmd_vel
```
(Ctrl-C 뒤)
```bash
ros2 param set /keys_to_twist linear_scale 0.3
ros2 param set /keys_to_twist linear_scale 1
ros2 topic pub --once /keys std_msgs/msg/String "{data: w}"
ros2 topic echo /cmd_vel --once --field twist.linear.x
ros2 param dump /keys_to_twist
```
실행할 때 값을 바로 주는 방법도 해 봅니다(터미널 1을 Ctrl-C 후).
```bash
ros2 run teleop_bot keys_to_twist_parameterized --ros-args -p linear_scale:=0.2 -p angular_scale:=0.8
```

**관찰**:
- `param list`에 `angular_scale`, `linear_scale`, `start_type_description_service`, `use_sim_time`이 나옵니다. 뒤의 두 개는 모든 노드에 자동으로 생기는 파라미터입니다.
- `param get`은 `Double value is: 0.1`입니다.
- `topic hz`는 약 10 Hz입니다. 실습 8-2와 달리 키를 누르지 않아도 계속 나옵니다.
- `param set ... 0.3`은 `Set parameter successful`, `param set ... 1`은 `Setting parameter failed: Wrong parameter type, expected 'Type.DOUBLE' got 'Type.INTEGER'`입니다. `1`은 정수로 해석되기 때문입니다. `1.0`으로 써야 합니다.
- `w`를 넣은 뒤 echo는 `0.3`입니다.
- `param dump`는 `/keys_to_twist:` 아래 `ros__parameters:` 블록을 yaml로 출력합니다. 다음 실습에서 이 형식으로 파일을 만듭니다.

**생각해 볼 질문**: `declare_parameter`를 지우고 `get_parameter`만 남기면 실행 결과가 어떻게 될까요? (Q3)

### 실습 8-4. yaml 파라미터 파일
**준비**: 실습 8-3까지 빌드된 상태.

**직접 입력**: `~/rosbook_ws/src/teleop_bot/config/keys_to_twist.yaml` (디렉터리 `config`를 먼저 만듭니다: `mkdir -p ~/rosbook_ws/src/teleop_bot/config`)
```yaml
keys_to_twist:
  ros__parameters:
    linear_scale: 0.2
    angular_scale: 0.8
    linear_accel: 0.5
    angular_accel: 1.0
```

**줄 단위 해설**:
| 줄 | 설명 |
|---|---|
| 1 | 이 값을 적용할 노드 이름입니다. 실행 중인 노드 이름과 다르면 조용히 무시됩니다. |
| 2 | ROS 2 파라미터 파일의 고정 키입니다. 철자가 틀리면 파일 전체가 거부됩니다. |
| 3~4 | 배율 두 개입니다. 실수로 적어야 double 선언과 맞습니다. |
| 5~6 | 다음 실습(ramp)에서 쓸 가속도입니다. 지금 노드는 이 이름을 선언하지 않았으므로 무시됩니다. |

이 파일은 `setup.py`에 설치 대상으로 등록하지 않고 원본 경로로 넘깁니다(설치 방법은 launch 파일을 다루는 장에서 봅니다).
```bash
ros2 run teleop_bot keys_to_twist_parameterized \
  --ros-args --params-file ~/rosbook_ws/src/teleop_bot/config/keys_to_twist.yaml
```
다른 터미널에서:
```bash
ros2 param get /keys_to_twist linear_scale
ros2 param list /keys_to_twist
```

**관찰**: `linear_scale`이 `0.2`입니다. `param list`에는 `linear_accel`, `angular_accel`이 없습니다. 선언하지 않은 파라미터는 파일에 있어도 노드에 생기지 않습니다.

**생각해 볼 질문**: yaml 첫 줄을 `keys_to_twistt`로 틀리면 어떤 메시지가 나올까요? (Q4)

### 실습 8-5. ramp: 가감속 제한
**준비**: 실습 8-4의 yaml.

**직접 입력**: `~/rosbook_ws/src/teleop_bot/teleop_bot/keys_to_twist_with_ramps.py`
```python
import math

from geometry_msgs.msg import TwistStamped
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import String

# key: (angular.z, linear.x)
KEY_MAPPING = {
    'w': (0.0, 1.0),
    'x': (0.0, -1.0),
    'a': (1.0, 0.0),
    'd': (-1.0, 0.0),
    's': (0.0, 0.0),
}


def ramped_vel(v_prev, v_target, dt, accel):
    step = accel * dt
    if abs(v_target - v_prev) <= step:
        return v_target
    return v_prev + math.copysign(step, v_target - v_prev)


class KeysToTwistWithRamps(Node):
    def __init__(self):
        super().__init__('keys_to_twist')
        self.declare_parameter('linear_scale', 0.1)
        self.declare_parameter('angular_scale', 0.1)
        self.declare_parameter('linear_accel', 1.0)
        self.declare_parameter('angular_accel', 1.0)
        self.twist_pub = self.create_publisher(TwistStamped, 'cmd_vel', 1)
        self.keys_sub = self.create_subscription(String, 'keys', self.keys_callback, 10)
        self.target_angular = 0.0
        self.target_linear = 0.0
        self.last_twist = TwistStamped()
        self.last_send_time = self.get_clock().now()
        self.timer = self.create_timer(0.05, self.send_twist)

    def keys_callback(self, msg):
        if len(msg.data) == 0 or msg.data[0] not in KEY_MAPPING:
            return
        angular, linear = KEY_MAPPING[msg.data[0]]
        self.target_angular = angular * self.get_parameter('angular_scale').value
        self.target_linear = linear * self.get_parameter('linear_scale').value

    def send_twist(self):
        now = self.get_clock().now()
        dt = (now - self.last_send_time).nanoseconds / 1e9
        self.last_send_time = now
        twist = self.last_twist.twist
        twist.angular.z = ramped_vel(
            twist.angular.z, self.target_angular, dt,
            self.get_parameter('angular_accel').value)
        twist.linear.x = ramped_vel(
            twist.linear.x, self.target_linear, dt,
            self.get_parameter('linear_accel').value)
        self.last_twist.header.stamp = now.to_msg()
        self.twist_pub.publish(self.last_twist)


def main(args=None):
    rclpy.init(args=args)
    node = KeysToTwistWithRamps()
    try:
        rclpy.spin(node)
    except (KeyboardInterrupt, ExternalShutdownException):
        pass
    finally:
        node.destroy_node()
        rclpy.try_shutdown()


if __name__ == '__main__':
    main()
```

**줄 단위 해설**:
| 줄 | 설명 |
|---|---|
| 19~23 | 한 주기에 바뀔 수 있는 최대량은 `가속도 × dt`입니다. 목표까지 남은 차이가 그보다 작으면 목표값을 그대로 쓰고, 크면 목표 방향으로 그만큼만 움직입니다. `math.copysign`은 크기는 첫 인자, 부호는 둘째 인자에서 가져옵니다. |
| 29~32 | 배율 둘과 가속도 둘을 선언합니다. 가속도 단위는 직진 m/s², 회전 rad/s²입니다. |
| 35~36 | 키는 이제 "목표 속도"만 정합니다. |
| 38 | 직전 발행 시각입니다. 실제로 흐른 시간을 dt로 쓰기 위해 보관합니다. |
| 39 | 20 Hz로 발행합니다. 주기가 짧을수록 속도 변화가 부드럽습니다. |
| 49~51 | 이번 주기의 dt를 노드 시계로 구합니다. 타이머가 조금 늦게 불려도 실제 경과 시간만큼만 가속합니다. |
| 52~58 | 보관해 둔 마지막 속도에서 목표 쪽으로 한 걸음 움직입니다. 가속도는 매번 파라미터에서 읽어 실행 중 변경을 반영합니다. |
| 59~60 | stamp를 찍어 발행합니다. |

빌드 후 yaml과 함께 실행합니다.
```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select teleop_bot
ros2 run teleop_bot keys_to_twist_with_ramps \
  --ros-args --params-file ~/rosbook_ws/src/teleop_bot/config/keys_to_twist.yaml
```
터미널 2:
```bash
ros2 param get /keys_to_twist linear_accel
ros2 topic echo /cmd_vel --field twist.linear.x
```
터미널 3:
```bash
ros2 topic pub --once /keys std_msgs/msg/String "{data: w}"
```

**관찰**:
- `linear_accel`은 `0.5`입니다(파일 값이 기본값 1.0을 덮어씀).
- echo가 `0.0`에서 시작해 `0.025`, `0.05`, `0.075` ... 로 0.05초마다 0.025씩 오르다가 `0.2`에서 멈춥니다. 0.2 m/s까지 약 0.4초가 걸립니다(0.2 ÷ 0.5 m/s²).
- `s`를 넣으면 같은 기울기로 0까지 내려갑니다.
- 참고로 Waffle Pi 모델 파일의 DiffDrive 플러그인에도 `max_linear_acceleration` 1.0이 들어 있습니다(`grep -n acceleration /opt/ros/jazzy/share/turtlebot3_gazebo/models/turtlebot3_waffle_pi/model.sdf`). 시뮬도 자체적으로 가속을 제한하지만, 명령 자체를 부드럽게 만드는 것은 별개의 일입니다.

**생각해 볼 질문**: `linear_accel`을 `0.0`으로 바꾸면 어떻게 될까요? 음수로 바꾸면요? (Q5)

### 실습 8-6. 시뮬에서 몰아 보기
**준비**: 터미널 3개. 터미널 1에서 시뮬 실행(`ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py`).

**직접 입력**: 터미널 2
```bash
ros2 run teleop_bot keys_to_twist_with_ramps --ros-args \
  --params-file ~/rosbook_ws/src/teleop_bot/config/keys_to_twist.yaml -p use_sim_time:=true
```
터미널 3 (이 터미널을 클릭해 둔 채로 키를 누릅니다)
```bash
ros2 run teleop_bot key_publisher
```
`w`로 출발, `a`/`d`로 회전, `s`로 정지합니다. 운전 중에 다른 터미널에서 `ros2 param set /keys_to_twist linear_scale 0.1`로 속도를 낮춰 봅니다.

**관찰**:
- 로봇이 부드럽게 출발하고 멈춥니다. `a`는 왼쪽(반시계)으로 돕니다.
- `--params-file` 뒤에 `-p`를 이어 쓰면 두 방법이 함께 적용됩니다.
- `ros2 node info /keys_to_twist`로 `/keys` 구독과 `/cmd_vel` 발행을 확인합니다.

**생각해 볼 질문**: 터미널 3의 `key_publisher`만 끄면 로봇은 어떻게 될까요? 터미널 2의 노드를 끄면요? (Q6)

### 실습 8-7. rviz2로 로봇이 보는 것 보기
**준비**: 실습 8-6이 실행 중입니다.

**직접 입력**: 터미널 4
```bash
ros2 run rviz2 rviz2 --ros-args -p use_sim_time:=true
```
rviz2 창에서 다음을 차례로 합니다.
1. 왼쪽 Displays 패널의 Global Options > Fixed Frame을 `map`에서 `odom`으로 바꿉니다.
2. 아래쪽 Add 버튼 > By display type > `TF`를 추가합니다.
3. Add > By topic > `/scan` 아래 `LaserScan`을 추가합니다. Size(m)를 0.05 정도로 키우면 잘 보입니다.
4. Add > By display type > `RobotModel`을 추가하고 Description Topic에 `/robot_description`을 고릅니다.
5. Add > By topic > `/odom` 아래 `Odometry`를 추가합니다.
6. (선택) Add > By topic > `/camera/image_raw` 아래 `Image`를 추가합니다.

이미 만들어진 설정 파일로 같은 화면을 한 번에 열 수도 있습니다.
```bash
ros2 run rviz2 rviz2 -d $(ros2 pkg prefix turtlebot3_gazebo)/share/turtlebot3_gazebo/rviz/tb3_gazebo.rviz \
  --ros-args -p use_sim_time:=true
```

**관찰**:
- Fixed Frame이 `map`이면 Global Status가 오류(빨간색)입니다. 이 시뮬의 TF 트리에 `map`이 없기 때문입니다. `odom`으로 바꾸면 사라집니다.
- LaserScan 점들이 월드의 기둥 모양을 따라 찍힙니다. 키로 로봇을 움직이면 점과 로봇 모델이 함께 움직이고, Odometry 화살표가 지나온 자리에 남습니다.
- RobotModel이 보이지 않고 상태가 경고이면, RobotModel의 Description Topic 아래 Durability Policy를 `Transient Local`로 바꿉니다. `/robot_description`은 한 번만 발행되는 TRANSIENT_LOCAL 토픽이라, 나중에 붙는 rviz2가 VOLATILE로 구독하면 받지 못합니다(6장 Q6).

**생각해 볼 질문**: Fixed Frame을 `base_footprint`로 바꾸고 운전하면 화면이 어떻게 보일까요? (Q7)

### 실습 8-8. 설치된 teleop_twist_keyboard와 비교
**준비**: 시뮬 실행 중. 실습 8-6의 두 노드는 끕니다(한 토픽에 두 조종기가 동시에 명령을 내지 않도록).

**직접 입력**:
```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args -p stamped:=true -p use_sim_time:=true
```
다른 터미널에서:
```bash
ros2 topic info -v /cmd_vel
ros2 param get /teleop_twist_keyboard stamped
ros2 param set /teleop_twist_keyboard speed 0.2
ros2 topic hz /cmd_vel
```

**관찰**:
- 화면 안내대로 `i` 전진, `j`/`l` 회전, `k` 정지, `,` 후진이고, `q`/`z`로 속도 배율을 바꿉니다.
- `stamped:=true`를 주어야 `/cmd_vel`의 publisher 타입이 `TwistStamped`가 됩니다. 기본값(false)이면 Twist를 내므로 로봇이 움직이지 않습니다(4절 첫 행과 같은 증상).
- `param set ... speed`는 `Trying to set a read-only parameter: speed.`로 거부됩니다. 이 노드는 파라미터를 읽기 전용으로 선언해 시작할 때만 정할 수 있습니다. 우리 노드는 실행 중에 바꿀 수 있게 만들었습니다.
- `topic hz`는 키를 누를 때만 값이 나옵니다. 이 노드는 실습 8-2처럼 키 이벤트마다 발행하는 방식입니다. 종료할 때는 정지 명령을 한 번 보냅니다.
- 이 노드도 키 입력과 발행을 한 프로세스 안에서 처리합니다. 우리는 둘을 두 노드로 나눴으므로 `/keys`를 다른 입력(예: 웹 버튼)으로 바꿔 끼울 수 있습니다.

**생각해 볼 질문**: 우리 `keys_to_twist`와 `teleop_twist_keyboard`를 동시에 실행하면 `/cmd_vel`에서 무슨 일이 생길까요? (Q8)

## 4. 일부러 망가뜨려 보기
| 바꿀 것 | 예상 증상 | 원인을 확인하는 명령 |
|---|---|---|
| `keys_to_twist_with_ramps.py`의 메시지를 `Twist`로 바꿔(가져오기, publisher, `.twist` 접근 수정) 시뮬에서 운전 | 키를 눌러도 로봇이 움직이지 않습니다. | `ros2 topic list -t`에서 `/cmd_vel` 타입이 두 개, `ros2 topic info -v /cmd_vel` |
| `teleop_twist_keyboard`를 `stamped:=true` 없이 실행 | 같은 증상입니다. | 위와 같음 |
| yaml 첫 줄 노드 이름 오타(`keys_to_twistt`) | 오류 없이 기본값(0.1)이 쓰입니다. | `ros2 param get /keys_to_twist linear_scale` |
| `key_publisher`의 토픽을 `'key'`로 오타 | `keys_to_twist`가 아무 키도 받지 못합니다. | `ros2 node info /keyboard_driver`, `ros2 topic info /keys`의 Publisher count: 0 |
| 운전 중 `keys_to_twist_with_ramps` 노드를 Ctrl-C로 종료 | 마지막 명령 이후 로봇의 동작을 관찰합니다. 이 노드는 종료 때 정지 명령을 보내지 않습니다. | `ros2 topic hz /cmd_vel`, Gazebo 화면 |
| `ros2 param set /keys_to_twist linear_accel 1` (정수) | `Setting parameter failed: Wrong parameter type ...`이 나오고 값이 그대로입니다. | `ros2 param get /keys_to_twist linear_accel` |
| QoS 불일치: `ros2 topic echo /keys --qos-durability transient_local` | `key_publisher`(VOLATILE)와 호환되지 않아 echo가 아무것도 받지 못하고 incompatible QoS 경고를 냅니다. | `ros2 topic info -v /keys` |
| `use_sim_time` 없이 `keys_to_twist_with_ramps`를 시뮬과 함께 실행 | 운전은 되지만 `/cmd_vel` stamp가 벽시계입니다. Gazebo를 일시정지해도 ramp가 계속 진행됩니다. | `ros2 topic echo /cmd_vel --field header.stamp`, `ros2 topic echo /clock --once` |
| rviz2를 `use_sim_time` 없이 실행 | LaserScan이 안 보이거나 TF 관련 경고(오래된 데이터, 외삽 오류)가 납니다. | rviz2의 Global Status와 각 Display의 Status |

## 5. 확인 질문
<details><summary>Q1. key_publisher를 launch나 리다이렉트로 실행하면?</summary>

표준 입력이 터미널이 아니므로 `termios.tcgetattr`가 `termios.error: (25, 'Inappropriate ioctl for device')`로 실패하고 노드가 바로 종료됩니다. `ros2 launch`는 노드의 표준 입력을 터미널에 연결하지 않으므로, 키 입력 노드는 별도 터미널에서 `ros2 run`으로 실행합니다.

</details>

<details><summary>Q2. 이벤트 방식에서 로봇은 언제까지 움직이나요?</summary>

다음 키가 올 때까지, 또는 받는 쪽(Gazebo DiffDrive)이 스스로 정한 규칙에 따라 움직입니다. 보내는 쪽이 갑자기 죽거나 통신이 끊기면 받는 쪽은 "정지"인지 "아직 같은 명령"인지 구분할 수 없습니다. 주기 발행으로 바꾸면 받는 쪽은 "일정 시간 명령이 없으면 멈춘다"는 안전 규칙을 둘 수 있습니다.

</details>

<details><summary>Q3. declare_parameter 없이 get_parameter만 쓰면?</summary>

키가 들어와 `get_parameter('linear_scale')`이 불리는 순간 `ParameterNotDeclaredException`이 나서 콜백이 실패하고 노드가 종료됩니다. ROS 2 노드는 기본적으로 선언한 파라미터만 가집니다. 또 `ros2 param set`으로도 선언되지 않은 파라미터를 만들 수 없습니다.

</details>

<details><summary>Q4. yaml의 노드 이름이 틀리면?</summary>

아무 메시지도 나오지 않습니다. 파일은 정상으로 읽히지만 그 이름의 노드가 없으므로 어떤 노드에도 적용되지 않고, 노드는 기본값을 씁니다. 그래서 파라미터 파일을 바꾼 뒤에는 `ros2 param get`으로 실제 값을 확인하는 습관이 필요합니다. 모든 노드에 적용하려면 노드 이름 자리에 `/**`를 쓸 수 있습니다.

</details>

<details><summary>Q5. linear_accel을 0이나 음수로 바꾸면?</summary>

0이면 한 주기에 바뀔 수 있는 양이 0이라 속도가 영원히 바뀌지 않습니다. 음수이면 `step`이 음수가 되어 `abs(...) <= step` 조건이 항상 거짓이 되고, `copysign`은 크기를 절댓값으로 쓰므로 같은 크기의 양수 가속도처럼 움직입니다. 다만 목표값에 딱 맞춰 멈추는 분기를 타지 못하므로 목표 근처에서 한 걸음씩 앞뒤로 흔들립니다. 둘 다 의도와 다르므로, 실전 코드에서는 `ParameterDescriptor`의 범위 지정이나 값 검사 콜백으로 막습니다.

</details>

<details><summary>Q6. 노드 하나씩 끄면?</summary>

`key_publisher`만 끄면 `keys_to_twist_with_ramps`는 마지막 목표 속도를 계속 20 Hz로 보내므로 로봇이 계속 움직입니다. 터미널 2의 노드를 끄면 `/cmd_vel`의 publisher가 사라지고, 이후 동작은 Gazebo DiffDrive가 마지막 명령을 어떻게 다루는지에 달려 있습니다. 같은 DiffDrive 시스템을 쓰는 16~17장 로봇의 검증에서는 마지막 명령을 계속 수행했으므로, TB3도 계속 움직일 것으로 예상합니다. 어느 쪽이든 "입력이 끊기면 멈춘다"는 처리가 없다는 점이 이 설계의 약점입니다.

</details>

<details><summary>Q7. Fixed Frame을 base_footprint로 바꾸면?</summary>

로봇이 화면 가운데에 고정되고 대신 레이저 점(주변 세계)이 반대로 움직입니다. Fixed Frame은 "화면에서 움직이지 않는 좌표계"를 고르는 설정이기 때문입니다. 이 상태에서는 Odometry 화살표의 궤적이 의미 있게 쌓이지 않습니다.

</details>

<details><summary>Q8. 두 조종 노드를 동시에 실행하면?</summary>

`/cmd_vel`에 publisher가 둘 생기고, 받는 쪽은 둘의 명령을 도착한 순서대로 섞어 받습니다. 우리 노드가 20 Hz로 "정지"를 계속 보내는 동안 다른 쪽 키 명령은 곧바로 덮어써집니다. ROS 2는 한 토픽에 여러 publisher를 허용하므로 오류는 나지 않습니다. 여러 입력을 우선순위로 합치려면 `twist_mux` 같은 중재 노드를 씁니다.

</details>

## 6. 원서 대조 메모
- PDF p.134의 키 대응표(그리고 이어지는 예제들)에서 `a`가 음의 회전(오른쪽)으로, `d`가 양의 회전으로 되어 있어 키 이름과 방향이 반대입니다. 원서도 PDF p.142의 예제에서 이를 바로잡습니다. 이 가이드는 처음부터 `a` = +z(왼쪽)로 썼습니다.
- PDF p.142~143의 ramp 예제는 전역 변수 이름을 한 이름으로 선언하고 다른 이름으로 사용합니다. 그대로 실행하면 이름 오류가 납니다. 이 가이드는 클래스 속성으로 바꿨습니다.
- PDF p.144의 실행 명령에서 두 파라미터 사이에 공백이 빠져 하나의 인자로 붙어 있습니다.
- PDF p.146은 실행할 스크립트 이름을 앞에서 만든 파일과 다른 이름으로 적고 있습니다.
- 원서 코드는 Python 2 문법(`has_key`, `print` 문)을 씁니다. Python 3에서는 `in`과 `print()`를 쓰고, 이 가이드는 로그에 `get_logger()`를 씁니다.
- 원서는 publisher를 노드 초기화보다 먼저 만듭니다. ROS 1에서만 가능한 순서입니다.
- 원서는 `tty.setraw`를 써서 Ctrl-C가 신호로 전달되지 않습니다. 이 가이드는 `setcbreak`를 써서 Ctrl-C로 정상 종료하고 터미널 설정을 되돌립니다.
- 원서의 rviz 설명(PDF p.146~154)은 ROS 1 rviz 화면 기준입니다. rviz2도 Displays, Fixed Frame, Add 구조는 같지만, `use_sim_time` 지정과 RobotModel의 Description Topic(그리고 Durability)이 추가로 필요합니다.
- 원서의 `rqt_plot` 사용(PDF p.137~138)은 ROS 2에서도 같은 개념이며, 필드 경로를 `/cmd_vel/twist/linear/x`처럼 TwistStamped 구조에 맞춰 적습니다.

## 7. 이 문서의 검증 상태
- 확인함:
  - `ros2 pkg create` 결과와 네 노드를 `~/guide_verify/C/ws`에서 빌드했고, `ament_flake8`, `ament_pep257` 검사에서 문제가 없었습니다.
  - `key_publisher`를 가상 터미널(pty)에서 실행해 `w`, `a`, `d`가 `/keys`로 나오고 위쪽 화살표가 세 메시지(`\e`, `[`, `A`)로 나오는 것을 확인했습니다(Fast DDS 실행). 터미널 없이 실행하면 `termios.error: (25, 'Inappropriate ioctl for device')`로 끝나는 것을 확인했습니다.
  - Cyclone DDS에서: `keys_to_twist`가 `w`에 `linear.x` 1.0, `a`에 `angular.z` 1.0을 내고 `q`는 무시하는 것, 키가 없으면 `/cmd_vel`이 나오지 않는 것을 확인했습니다.
  - Cyclone DDS에서: `keys_to_twist_parameterized`의 `param list`(네 항목), `param get`(`Double value is: 0.1`), 10 Hz 발행, `param set 0.3` 성공과 `param set 1`의 타입 오류 문구, `w` 뒤 `0.3`, `param dump` 출력을 확인했습니다.
  - Cyclone DDS에서: yaml을 `--params-file`로 준 `keys_to_twist_with_ramps`의 `linear_accel` 0.5와 `0.0 → 0.025 → 0.05 → ... → 0.2` 상승을 확인했습니다.
  - `teleop_twist_keyboard` 2.4.1을 `stamped:=true`로 실행해 `/cmd_vel` 타입 TwistStamped, `stamped` True, `speed` 변경 시 `Trying to set a read-only parameter: speed.`를 확인했고(Fast DDS 실행), 키 처리 방식은 설치된 소스를 읽어 확인했습니다.
  - `tb3_gazebo.rviz`의 Fixed Frame(`odom`)과 Display 구성(TF, LaserScan, Odometry, RobotModel)을 파일로 확인했습니다. DiffDrive의 `max_linear_acceleration` 1.0은 `model.sdf`에서 확인했습니다.
- 확인 못 함:
  - 시뮬에서의 실제 운전, 노드를 끈 뒤 로봇의 움직임(DiffDrive 명령 시간 초과 여부): 확인 못 함(시뮬 필요).
  - rviz2 화면, Fixed Frame 오류 표시, RobotModel Durability 설정의 효과, rqt_plot 그래프: 확인 못 함(GUI).
  - `--qos-durability transient_local` echo와 `/keys`의 비호환 경고, yaml 노드 이름 오타, `declare_parameter` 생략 시 예외, `linear_accel` 0과 음수의 동작: 확인 못 함(규칙과 코드에서 유추).
