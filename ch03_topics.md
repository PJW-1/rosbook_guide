# 3장. 토픽

- 원서: Chapter 3. Topics, PDF p.51~70 (인쇄 쪽 = PDF 쪽 - 20)
- 선행 조건: 2장 실습 2-5와 2-7을 마쳐서 `~/rosbook_ws/src/basics` 패키지가 있고 빌드되어야 합니다.
- 새로 설치할 것: 없음

## 이 장에서 체감할 구조
토픽은 이름과 타입과 QoS로 정해지는 단방향 통로입니다. publisher는 받는 쪽이 누구인지 모르고, subscriber도 보내는 쪽이 누구인지 모릅니다.
둘을 이어 주는 것은 이름이 같고, 타입이 같고, QoS가 서로 맞는다는 조건뿐입니다. 셋 중 하나라도 어긋나면 대부분 오류 없이 조용히 아무것도 전달되지 않습니다.

```
[topic_publisher] --(/counter, std_msgs/msg/Int32, RELIABLE+VOLATILE)--> [topic_subscriber]
[message_publisher] --(/complex, basics_interfaces/msg/Complex)--> [message_subscriber]
              (/number) --> [doubler] --> (/doubled)
```

## 1. 목표와 개념

원서 3장은 rospy로 토픽에 발행하고 구독하는 노드(원서 PDF p.52~58), 늦게 접속한 노드도 마지막 값을 받게 하는 latched 토픽(p.58~59), 기본 메시지 타입(p.59~61), 직접 정의한 메시지(p.61~67), 발행과 구독을 한 노드에서 함께 하는 예(p.67~68)를 다룹니다. 이 장은 같은 흐름을 rclpy로 다시 만듭니다. 여기서 만드는 `topic_publisher`(토픽 `counter`, 타입 `std_msgs/msg/Int32`)는 20장과 23장에서 다시 씁니다.

**publisher와 subscriber.** rclpy(ROS 2의 Python 클라이언트 라이브러리)에서 노드는 `Node` 클래스를 상속해서 만듭니다. `create_publisher(타입, 토픽 이름, QoS)`로 publisher를, `create_subscription(타입, 토픽 이름, 콜백, QoS)`로 subscriber를 만듭니다. 주기적인 일은 `create_timer(주기, 콜백)`로 맡깁니다. `rclpy.spin(node)`은 메시지 도착과 타이머 만료를 기다렸다가 해당 콜백을 불러 주는 반복문입니다.

**QoS (Quality of Service).** 토픽 연결의 전달 방식을 정하는 설정 묶음입니다. 이 장에서는 셋을 봅니다.
- history와 depth: 보내지 못했거나 아직 처리하지 못한 메시지를 몇 개까지 쌓아 둘지. 숫자 `10`만 넘기면 `KEEP_LAST`, depth 10이라는 뜻입니다. 원서의 `queue_size`에 해당합니다.
- reliability: `RELIABLE`은 잃어버린 메시지를 다시 보내고, `BEST_EFFORT`는 다시 보내지 않습니다.
- durability: `VOLATILE`은 지금 연결된 subscriber에게만 보내고, `TRANSIENT_LOCAL`은 publisher가 최근 메시지를 보관했다가 나중에 접속한 subscriber에게도 보내 줍니다. 원서의 latched 토픽이 ROS 2에서는 `TRANSIENT_LOCAL`입니다.

publisher는 "이만큼 해 줄 수 있다"를 내놓고 subscriber는 "이만큼은 해 줘야 한다"를 요구합니다. 내놓는 쪽이 요구하는 쪽보다 같거나 강하면 연결되고, 약하면 연결되지 않습니다.

비유: 택배 회사(publisher)가 "배송 추적 가능"을 내걸면 추적을 원하는 손님과 원하지 않는 손님 모두 받을 수 있지만, "추적 불가" 회사는 추적을 꼭 원하는 손님과 계약할 수 없습니다.

**메시지 정의.** 메시지 타입은 `.msg` 파일에 "타입 이름" 줄을 나열해서 정의합니다. 빌드할 때 rosidl이 이 파일로부터 Python 클래스와 C++ 구조체를 만들어 줍니다. ROS 2에서는 메시지를 정의하는 패키지를 `ament_cmake` 형식으로 따로 만드는 것이 관례입니다. 그래서 이 장에서 `basics_interfaces` 패키지를 새로 만듭니다.

## 2. 원서(ROS 1)와 달라지는 점

| 원서 (ROS 1) | ROS 2 Jazzy | 이유와 주의점 |
|---|---|---|
| `rospy.init_node()` 후 전역 함수 호출 | `Node`를 상속한 클래스, `rclpy.init()`, `rclpy.spin(node)` | 한 프로세스에 노드를 여럿 둘 수 있게 노드가 객체가 되었습니다. |
| `rospy.Publisher('counter', Int32, queue_size=...)` | `self.create_publisher(Int32, 'counter', 10)` | 인자 순서가 타입, 이름, QoS입니다. QoS는 생략할 수 없습니다. |
| `rospy.Subscriber('counter', Int32, callback)` | `self.create_subscription(Int32, 'counter', self.callback, 10)` | 반환값을 변수에 붙잡아 둬야 구독이 유지됩니다. |
| `rospy.Rate(2)`와 `while not rospy.is_shutdown()` | `self.create_timer(0.5, self.timer_callback)` | 반복문 대신 타이머 콜백을 씁니다. |
| `rospy.loginfo()` | `self.get_logger().info()` | |
| `latch=True` | `QoSProfile(depth=1, durability=DurabilityPolicy.TRANSIENT_LOCAL)` | 받는 쪽도 TRANSIENT_LOCAL로 요청해야 지난 메시지를 받습니다. |
| `std_msgs/Int32` | `std_msgs/msg/Int32` | 타입 이름 가운데 `msg`가 들어갑니다. |
| `rostopic hz`, `rostopic info`, `rostopic pub` | `ros2 topic hz`, `ros2 topic info -v`, `ros2 topic pub` | `-v`를 붙이면 QoS까지 보여 줍니다. |
| `rosmsg show` | `ros2 interface show` | |
| `basics` 패키지 안의 `msg/Complex.msg`, `message_generation` | 별도 `ament_cmake` 패키지 `basics_interfaces`, `rosidl_default_generators` | `ament_python` 패키지에서는 메시지를 생성할 수 없습니다. |
| 메시지 필드에 범위를 넘는 값을 넣으면 rospy가 직렬화할 때 오류 | Jazzy rclpy는 기본적으로 범위 검사를 하지 않고, 값이 잘려서 전송됨 | `ROS_PYTHON_CHECK_FIELDS=1`이면 대입할 때 검사합니다. 실습 3-2에서 확인합니다. |

## 3. 실습

### 실습 3-1. 숫자를 세는 publisher

**준비**: 터미널 2개. 2장 실습 2-7까지의 `basics` 패키지.

**직접 입력**: 파일 `~/rosbook_ws/src/basics/basics/topic_publisher.py`

```python
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import Int32


class TopicPublisher(Node):
    def __init__(self):
        super().__init__('topic_publisher')
        self.pub = self.create_publisher(Int32, 'counter', 10)
        self.count = 0
        self.timer = self.create_timer(0.5, self.timer_callback)

    def timer_callback(self):
        msg = Int32()
        msg.data = self.count
        self.pub.publish(msg)
        self.count += 1


def main(args=None):
    rclpy.init(args=args)
    node = TopicPublisher()
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
| 1 | ROS 2 Python 클라이언트 라이브러리를 가져옵니다. |
| 2 | 다른 곳에서 ROS 2를 종료시켰을 때 `spin`이 던지는 예외입니다. 29~30줄의 정리 코드로 가기 위해 잡습니다. |
| 3 | 모든 노드의 부모 클래스입니다. |
| 4 | 32비트 정수 하나(`data`)를 담는 메시지 타입입니다. 빌드할 때 생성된 Python 클래스를 가져옵니다. |
| 7 | `Node`를 상속해서 우리 노드를 정의합니다. |
| 9 | 부모 생성자에 노드 이름을 넘깁니다. 그래프에는 `/topic_publisher`로 나타납니다. |
| 10 | `counter` 토픽에 `Int32`를 발행하는 publisher를 만듭니다. `10`은 QoS로, KEEP_LAST depth 10과 기본값 RELIABLE, VOLATILE을 뜻합니다. |
| 11 | 다음에 보낼 숫자입니다. |
| 12 | 0.5초마다 `timer_callback`을 부르는 타이머를 만듭니다. 즉 2 Hz로 발행합니다. 반환값을 `self.timer`에 붙잡아 둬야 타이머가 사라지지 않습니다. |
| 14~18 | 타이머가 부를 때마다 새 메시지를 만들어 숫자를 넣고, 발행한 뒤 숫자를 1 늘립니다. |
| 21~22 | `rclpy.init`은 ROS 2 통신을 준비합니다. `args`를 넘기면 `--ros-args` 뒤의 리매핑 같은 인자가 적용됩니다. |
| 23 | 노드 객체를 만듭니다. 이 순간 publisher와 타이머가 생깁니다. |
| 24~27 | `spin`은 타이머와 메시지를 기다리며 콜백을 부르는 반복문입니다. Ctrl-C가 들어오면 `KeyboardInterrupt`로 빠져나옵니다. |
| 28~30 | 어떻게 끝나든 노드를 정리하고 ROS 2를 종료합니다. `try_shutdown`은 이미 종료된 상태여도 오류를 내지 않습니다. |
| 33~34 | 파일을 `python3`로 직접 실행했을 때도 `main`이 불리게 합니다. |

`setup.py`의 `entry_points`에 등록합니다. 파일 `~/rosbook_ws/src/basics/setup.py`에서 `'console_scripts': [` 아래를 다음처럼 바꿉니다 (이 장 끝의 최종 형태는 실습 3-6에 전체를 싣습니다).

```python
        'console_scripts': [
            'topic_publisher = basics.topic_publisher:main',
        ],
```

`실행 파일 이름 = 모듈 경로:함수` 형식입니다. 빌드하면 `install/basics/lib/basics/topic_publisher` 실행 파일이 만들어지고, `ros2 run basics topic_publisher`가 그것을 실행합니다.

`package.xml`에 의존성을 추가합니다. 파일 `~/rosbook_ws/src/basics/package.xml`에서 `<license>` 줄 아래, 2장에서 넣은 `exec_depend` 위에 다음 두 줄을 넣습니다. `depend`는 빌드와 실행 모두에 필요하다는 뜻입니다.

```xml
  <depend>rclpy</depend>
  <depend>std_msgs</depend>
```

빌드하고 실행합니다 (터미널 A).

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics
source ~/rosbook_ws/install/setup.bash
ros2 run basics topic_publisher
```

**관찰**: 이 노드는 로그를 찍지 않으므로 터미널 A는 조용합니다. 터미널 B에서 확인합니다.

```bash
ros2 topic list -t
ros2 topic echo /counter
```

`/counter [std_msgs/msg/Int32]`가 보이고, `echo`는 `data: 9`, `---`처럼 숫자를 하나씩 보여 줍니다. Ctrl-C로 멈추고 다음을 실행합니다.

```bash
ros2 topic hz /counter
```

```
average rate: 2.000
	min: 0.500s max: 0.500s std dev: 0.00007s window: 4
```

몇 줄 본 뒤 Ctrl-C로 멈춥니다.

```bash
ros2 topic info -v /counter
```

publisher 항목에 `Node name: topic_publisher`, `Topic type: std_msgs/msg/Int32`, 그리고 QoS로 `Reliability: RELIABLE`, `History (Depth): KEEP_LAST (10)`, `Durability: VOLATILE`이 보입니다. 아직 구독자가 없으므로 `Subscription count: 0`입니다. 타입으로 토픽을 찾을 수도 있습니다.

```bash
ros2 topic find std_msgs/msg/Int32
```

**생각해 볼 질문**: 12번 줄을 `self.create_timer(...)`로만 쓰고 `self.timer =`를 지우면 어떻게 될지 예상해 보세요.

### 실습 3-2. 구독하는 노드

**준비**: 터미널 3개. 터미널 A에서 `ros2 run basics topic_publisher`가 실행 중이어야 합니다.

**직접 입력**: 파일 `~/rosbook_ws/src/basics/basics/topic_subscriber.py`

```python
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import Int32


class TopicSubscriber(Node):
    def __init__(self):
        super().__init__('topic_subscriber')
        self.sub = self.create_subscription(
            Int32, 'counter', self.callback, 10)

    def callback(self, msg):
        self.get_logger().info(f'{msg.data}')


def main(args=None):
    rclpy.init(args=args)
    node = TopicSubscriber()
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

| 줄 | 설명 |
|---|---|
| 1~4 | 실습 3-1과 같습니다. 받을 메시지 타입도 발행 쪽과 같은 `Int32`여야 합니다. |
| 9 | 노드 이름은 `topic_subscriber`입니다. |
| 10~11 | `counter` 토픽의 `Int32` 메시지를 받으면 `self.callback`을 부르는 subscriber를 만듭니다. QoS `10`은 publisher와 같은 기본값(RELIABLE, VOLATILE)입니다. 반환값을 `self.sub`에 붙잡아 둡니다. |
| 13~14 | 메시지 하나를 받을 때마다 불립니다. `msg`는 `Int32` 객체이고, `data` 값을 INFO 로그로 찍습니다. |
| 17~30 | 실습 3-1과 같은 형태의 `main`입니다. 이 노드는 타이머가 없고, `spin`이 메시지를 기다리다가 콜백을 부릅니다. |

`setup.py`의 `console_scripts`에 한 줄을 추가합니다.

```python
            'topic_subscriber = basics.topic_subscriber:main',
```

새 실행 파일을 등록했으므로 다시 빌드합니다. `--symlink-install`이라도 `entry_points`를 바꾸면 다시 빌드해야 합니다 (터미널 B).

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics
source ~/rosbook_ws/install/setup.bash
ros2 run basics topic_subscriber
```

**관찰**: `[INFO] [...] [topic_subscriber]: 20`처럼 publisher가 지금 보내는 숫자부터 찍힙니다. 0부터가 아닌 이유는 subscriber가 늦게 접속했고 토픽이 VOLATILE이기 때문입니다.

터미널 C에서 다른 publisher로 끼어들어 봅니다.

```bash
ros2 topic pub --once /counter std_msgs/msg/Int32 "{data: 1000000}"
```

터미널 B의 숫자 사이에 `1000000`이 한 번 끼어듭니다. subscriber는 누가 보냈는지 구분하지 않습니다.

이번에는 `Int32`의 범위(-2147483648 ~ 2147483647)를 넘는 값을 보냅니다.

```bash
ros2 topic pub --once /counter std_msgs/msg/Int32 "{data: 2147483648}"
```

오류 없이 발행되고, 터미널 B에는 `-2147483648`이 찍힙니다. 32비트에 담기지 않는 값이 잘려서 엉뚱한 수가 되었습니다. Jazzy의 rclpy는 기본적으로 필드 범위를 검사하지 않습니다. 검사를 켜고 Python에서 직접 확인해 봅니다.

```bash
ROS_PYTHON_CHECK_FIELDS=1 python3 -c "
from std_msgs.msg import Int32
m = Int32()
m.data = 2**31
"
```

`AssertionError: The 'data' field must be an integer in [-2147483648, 2147483647]`가 납니다. `ROS_PYTHON_CHECK_FIELDS` 없이 같은 코드를 실행하면 아무 오류도 나지 않습니다.

**생각해 볼 질문**: 터미널 A의 publisher를 Ctrl-C로 끄면 subscriber는 어떻게 될까요? 다시 켜면 숫자는 몇부터 찍힐까요?

### 실습 3-3. 늦게 와도 받는 토픽 (TRANSIENT_LOCAL)

**준비**: 터미널 2개. 실행 중인 노드는 모두 끕니다.

**직접 입력**: 파일 `~/rosbook_ws/src/basics/basics/latched_publisher.py`

```python
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, QoSProfile
from std_msgs.msg import Int32


class LatchedPublisher(Node):
    def __init__(self):
        super().__init__('latched_publisher')
        qos = QoSProfile(depth=1, durability=DurabilityPolicy.TRANSIENT_LOCAL)
        self.pub = self.create_publisher(Int32, 'latched', qos)
        msg = Int32()
        msg.data = 42
        self.pub.publish(msg)
        self.get_logger().info('published 42 once')


def main(args=None):
    rclpy.init(args=args)
    node = LatchedPublisher()
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

| 줄 | 설명 |
|---|---|
| 4 | QoS를 직접 구성하는 클래스와 durability 선택지를 가져옵니다. |
| 11 | 최근 1개를 보관하고(`depth=1`), 나중에 접속한 subscriber에게도 보내 주는(`TRANSIENT_LOCAL`) QoS를 만듭니다. reliability는 지정하지 않아 기본값 RELIABLE입니다. |
| 12 | 이 QoS로 `latched` 토픽 publisher를 만듭니다. |
| 13~16 | 시작할 때 `42`를 딱 한 번 발행하고 로그를 남깁니다. 타이머가 없으므로 다시 발행하지 않습니다. |
| 22~25 | 그래도 `spin`으로 노드를 살려 둡니다. publisher가 살아 있어야 보관한 메시지를 늦게 온 subscriber에게 줄 수 있습니다. |

`setup.py`의 `console_scripts`에 `'latched_publisher = basics.latched_publisher:main',`을 추가하고 다시 빌드합니다. 터미널 A에서 실행합니다.

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics
source ~/rosbook_ws/install/setup.bash
ros2 run basics latched_publisher
```

몇 초 기다린 뒤 터미널 B에서 받아 봅니다. 아래 네 명령을 차례로 실행하고, 결과가 없으면 몇 초 뒤 Ctrl-C로 멈춥니다.

```bash
ros2 topic echo /latched --qos-durability volatile --qos-reliability reliable
ros2 topic echo /latched --qos-durability transient_local --qos-reliability reliable
ros2 topic echo /latched
ros2 run basics topic_subscriber --ros-args -r counter:=latched
```

**관찰**:

| 명령 | 결과 |
|---|---|
| `--qos-durability volatile` | 아무것도 받지 못합니다. 42는 이미 지나간 메시지입니다. |
| `--qos-durability transient_local --qos-reliability reliable` | `data: 42`를 받습니다. |
| 옵션 없는 `ros2 topic echo` | `data: 42`를 받습니다. Jazzy의 `echo`는 옵션이 없으면 발견한 publisher의 QoS에 맞춰 구독합니다. |
| `topic_subscriber`를 `latched`로 리매핑 | 아무것도 받지 못합니다. 코드에 QoS `10`, 즉 VOLATILE로 구독하기 때문입니다. |

`--qos-durability transient_local`만 주고 reliability를 빼면 이 PC에서는 받지 못했습니다. `ros2 topic echo`는 QoS 옵션을 하나라도 받으면 `sensor_data` 프로파일(BEST_EFFORT)을 바탕으로 삼고, 지정한 항목만 바꾸기 때문입니다. 즉 이 명령은 BEST_EFFORT와 TRANSIENT_LOCAL로 구독했고, 이 조합으로는 보관된 메시지를 받지 못했습니다. 늦게 온 subscriber에게 보관 메시지를 확실히 받으려면 durability와 reliability를 모두 맞춥니다.

`ros2 topic info -v /latched`로 publisher의 QoS가 `TRANSIENT_LOCAL`, `KEEP_LAST (1)`인 것도 확인합니다. 2장 실습 2-9의 `/tf_static`과 같은 설정입니다.

**생각해 볼 질문**: 지도처럼 크지만 거의 바뀌지 않는 데이터를 이런 토픽으로 보내면 무엇이 좋을까요? 반대로 센서 데이터에 쓰면 무엇이 문제일까요?

### 실습 3-4. QoS 조합 표 만들기

**준비**: 터미널 2개. `ros2 topic pub`과 `ros2 topic echo`의 QoS 옵션으로 직접 조합을 시험합니다.

**직접 입력**: 먼저 publisher BEST_EFFORT, subscriber RELIABLE 조합입니다.

터미널 A:

```bash
ros2 topic pub -r 2 /qos_test std_msgs/msg/Int32 "{data: 1}" --qos-reliability best_effort
```

터미널 B:

```bash
ros2 topic echo /qos_test --qos-reliability reliable
```

**관찰**: 터미널 B에 다음 경고가 나오고 아무것도 받지 못합니다.

```
New publisher discovered on topic '/qos_test', offering incompatible QoS. No messages will be received from it. Last incompatible policy: RELIABILITY
```

터미널 A에도 `New subscription discovered on topic '/qos_test', requesting incompatible QoS. No messages will be sent to it.`가 나옵니다. 나머지 조합은 옵션 값만 바꿔 같은 방법으로 시험합니다. durability를 시험할 때는 `--qos-durability transient_local` 또는 `volatile`을 양쪽에 주고, reliability는 양쪽 모두 `reliable`로 둡니다.

| publisher | subscriber | 결과 |
|---|---|---|
| RELIABLE | RELIABLE | 받음 |
| RELIABLE | BEST_EFFORT | 받음 |
| BEST_EFFORT | RELIABLE | 받지 못함 (RELIABILITY 경고) |
| BEST_EFFORT | BEST_EFFORT | 받음 |
| TRANSIENT_LOCAL | TRANSIENT_LOCAL | 받음 (늦게 와도 보관된 메시지까지) |
| TRANSIENT_LOCAL | VOLATILE | 받음 (접속한 뒤의 메시지만) |
| VOLATILE | TRANSIENT_LOCAL | 받지 못함 (DURABILITY 경고) |
| VOLATILE | VOLATILE | 받음 |

규칙은 하나입니다. publisher가 내놓는 것이 subscriber가 요구하는 것보다 약하면 연결되지 않습니다. 둘 다 연결이 안 되는 조합은 subscriber가 더 많이 요구한 경우입니다.

`topic_subscriber`(RELIABLE)를 BEST_EFFORT publisher와 이어 봐도 같은 RELIABILITY 경고가 subscriber 쪽 로그에 나옵니다.

```bash
ros2 run basics topic_subscriber
```

```bash
ros2 topic pub -r 2 /counter std_msgs/msg/Int32 "{data: 7}" --qos-reliability best_effort
```

**생각해 볼 질문**: 카메라 드라이버들은 흔히 BEST_EFFORT로 발행합니다. 이런 토픽을 받는 노드를 직접 쓸 때 QoS를 무엇으로 정해야 할까요?

### 실습 3-5. 메시지 정의 패키지 basics_interfaces

**준비**: 터미널 1개.

**직접 입력**:

```bash
cd ~/rosbook_ws/src
ros2 pkg create --build-type ament_cmake --license Apache-2.0 basics_interfaces
mkdir -p basics_interfaces/msg
```

`ament_cmake` 패키지에는 `CMakeLists.txt`, `package.xml`, `LICENSE`와 빈 `src/`, `include/basics_interfaces/` 폴더가 생깁니다. 메시지만 담을 패키지라서 `src/`와 `include/`는 쓰지 않습니다.

파일 `~/rosbook_ws/src/basics_interfaces/msg/Complex.msg`:

```
float32 real
float32 imaginary
```

| 줄 | 설명 |
|---|---|
| 1 | 32비트 실수 필드 `real`(실수부). `타입 이름` 형식입니다. |
| 2 | 32비트 실수 필드 `imaginary`(허수부). |

메시지 파일 이름은 대문자로 시작하는 CamelCase여야 합니다. 이 파일로부터 `basics_interfaces/msg/Complex` 타입이 만들어집니다.

파일 `~/rosbook_ws/src/basics_interfaces/CMakeLists.txt` 전체 (추가한 줄은 10~14번 줄입니다):

```cmake
cmake_minimum_required(VERSION 3.8)
project(basics_interfaces)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)

rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/Complex.msg"
)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  # the following line skips the linter which checks for copyrights
  # comment the line when a copyright and license is added to all source files
  set(ament_cmake_copyright_FOUND TRUE)
  # the following line skips cpplint (only works in a git repo)
  # comment the line when this package is in a git repo and when
  # a copyright and license is added to all source files
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
```

| 줄 | 설명 |
|---|---|
| 1~9 | `ros2 pkg create`가 만든 그대로입니다. |
| 10 | 메시지 코드 생성기(rosidl)를 찾습니다. |
| 12~14 | `msg/Complex.msg`로부터 Python, C++ 등의 코드를 생성하라고 지시합니다. 메시지 파일을 추가할 때마다 이 목록에 줄을 더합니다. |
| 16~26 | 생성된 테스트 설정입니다. 그대로 둡니다. |
| 28 | 패키지 설치 정보를 마무리합니다. 항상 마지막 줄입니다. |

파일 `~/rosbook_ws/src/basics_interfaces/package.xml` 전체 (추가한 줄은 11, 13, 15번 줄입니다. 관리자 줄은 생성된 값을 그대로 둡니다):

```xml
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>basics_interfaces</name>
  <version>0.0.0</version>
  <description>TODO: Package description</description>
  <maintainer email="pjw@todo.todo">pjw</maintainer>
  <license>Apache-2.0</license>

  <buildtool_depend>ament_cmake</buildtool_depend>
  <buildtool_depend>rosidl_default_generators</buildtool_depend>

  <exec_depend>rosidl_default_runtime</exec_depend>

  <member_of_group>rosidl_interface_packages</member_of_group>

  <test_depend>ament_lint_auto</test_depend>
  <test_depend>ament_lint_common</test_depend>

  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
```

| 줄 | 설명 |
|---|---|
| 11 | 빌드할 때 코드 생성기가 필요하다는 뜻입니다. |
| 13 | 생성된 메시지를 실행할 때 쓰는 런타임 라이브러리가 필요하다는 뜻입니다. |
| 15 | 이 패키지가 인터페이스(메시지) 패키지 묶음에 속한다고 표시합니다. 없으면 빌드가 실패합니다. |

빌드하고 확인합니다.

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics_interfaces
source ~/rosbook_ws/install/setup.bash
ros2 interface show basics_interfaces/msg/Complex
ros2 interface package basics_interfaces
```

**관찰**: `interface show`는 `.msg` 파일 내용 그대로 `float32 real`, `float32 imaginary`를 보여 주고, `interface package`는 `basics_interfaces/msg/Complex`를 출력합니다. 생성된 Python 코드는 `~/rosbook_ws/install/basics_interfaces/lib/python3.12/site-packages/basics_interfaces/msg/_complex.py`에 있습니다. 열어 보면 `real`, `imaginary` 속성을 가진 클래스가 만들어져 있습니다.

비교로 기본 타입도 봅니다.

```bash
ros2 interface show std_msgs/msg/Int32
```

맨 위 주석에 이 타입이 Foxy부터 권장되지 않는다(deprecated)는 안내가 있습니다. `std_msgs`의 단순 타입은 의미가 담긴 이름이 없어서, 실제 프로젝트에서는 용도에 맞는 메시지를 정의하라는 뜻입니다. 이 가이드는 원서와 흐름을 맞추기 위해 연습용으로 계속 씁니다.

**생각해 볼 질문**: 원서처럼 `Complex.msg`를 `basics` 패키지 안에 두면 무엇이 문제일까요?

### 실습 3-6. 직접 정의한 메시지 주고받기

**준비**: 터미널 2개.

**직접 입력**: 파일 `~/rosbook_ws/src/basics/basics/message_publisher.py`

```python
from random import random

from basics_interfaces.msg import Complex
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node


class MessagePublisher(Node):
    def __init__(self):
        super().__init__('message_publisher')
        self.pub = self.create_publisher(Complex, 'complex', 10)
        self.timer = self.create_timer(0.5, self.timer_callback)

    def timer_callback(self):
        msg = Complex()
        msg.real = random()
        msg.imaginary = random()
        self.pub.publish(msg)


def main(args=None):
    rclpy.init(args=args)
    node = MessagePublisher()
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

| 줄 | 설명 |
|---|---|
| 1 | 0 이상 1 미만의 난수를 만드는 표준 라이브러리 함수입니다. |
| 3 | 실습 3-5에서 생성된 메시지 클래스를 가져옵니다. 패키지 이름 `basics_interfaces`, 모듈 `msg`, 클래스 `Complex`입니다. |
| 12 | `complex` 토픽에 `Complex` 메시지를 발행합니다. |
| 13 | 0.5초마다 발행합니다. |
| 16~19 | 메시지를 만들어 두 필드에 난수를 넣고 발행합니다. 필드 이름은 `.msg` 파일의 이름 그대로입니다. |
| 22~35 | 실습 3-1과 같은 `main`입니다. |

파일 `~/rosbook_ws/src/basics/basics/message_subscriber.py`

```python
from basics_interfaces.msg import Complex
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node


class MessageSubscriber(Node):
    def __init__(self):
        super().__init__('message_subscriber')
        self.sub = self.create_subscription(
            Complex, 'complex', self.callback, 10)

    def callback(self, msg):
        self.get_logger().info(
            f'real: {msg.real:.3f}, imaginary: {msg.imaginary:.3f}')


def main(args=None):
    rclpy.init(args=args)
    node = MessageSubscriber()
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

| 줄 | 설명 |
|---|---|
| 1 | 같은 메시지 클래스를 가져옵니다. |
| 10~11 | `complex` 토픽을 `Complex` 타입으로 구독합니다. |
| 13~15 | 받은 두 필드를 소수점 셋째 자리까지 로그로 찍습니다. |

`basics`가 이제 `basics_interfaces`를 쓰므로 의존성에 추가합니다. 이 장을 마친 시점의 `~/rosbook_ws/src/basics/package.xml` 전체:

```xml
<?xml version="1.0"?>
<?xml-model href="http://download.ros.org/schema/package_format3.xsd" schematypens="http://www.w3.org/2001/XMLSchema"?>
<package format="3">
  <name>basics</name>
  <version>0.0.0</version>
  <description>TODO: Package description</description>
  <maintainer email="pjw@todo.todo">pjw</maintainer>
  <license>Apache-2.0</license>

  <depend>rclpy</depend>
  <depend>std_msgs</depend>
  <depend>basics_interfaces</depend>

  <exec_depend>launch</exec_depend>
  <exec_depend>launch_ros</exec_depend>
  <exec_depend>demo_nodes_py</exec_depend>

  <test_depend>ament_copyright</test_depend>
  <test_depend>ament_flake8</test_depend>
  <test_depend>ament_pep257</test_depend>
  <test_depend>python3-pytest</test_depend>

  <export>
    <build_type>ament_python</build_type>
  </export>
</package>
```

12번 줄이 이번에 추가한 줄입니다. colcon은 이 줄을 보고 `basics_interfaces`를 `basics`보다 먼저 빌드합니다.

이 장을 마친 시점의 `~/rosbook_ws/src/basics/setup.py` 전체 (실습 3-7의 `doubler`까지 포함):

```python
from glob import glob

from setuptools import find_packages, setup

package_name = 'basics'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        ('share/' + package_name + '/launch', glob('launch/*.launch.py')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='pjw',
    maintainer_email='pjw@todo.todo',
    description='TODO: Package description',
    license='Apache-2.0',
    extras_require={
        'test': [
            'pytest',
        ],
    },
    entry_points={
        'console_scripts': [
            'topic_publisher = basics.topic_publisher:main',
            'topic_subscriber = basics.topic_subscriber:main',
            'latched_publisher = basics.latched_publisher:main',
            'message_publisher = basics.message_publisher:main',
            'message_subscriber = basics.message_subscriber:main',
            'doubler = basics.doubler:main',
        ],
    },
)
```

`maintainer`, `maintainer_email`은 `ros2 pkg create`가 채운 값 그대로 둡니다. 실습 3-7의 `doubler.py`를 아직 만들지 않았다면 마지막 등록 줄은 다음 실습에서 추가해도 됩니다.

두 패키지를 함께 빌드하고 실행합니다.

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics_interfaces basics
source ~/rosbook_ws/install/setup.bash
ros2 run basics message_publisher
```

터미널 B는 `basics_interfaces`를 처음 빌드하기 전에 열었을 수 있으므로 overlay를 다시 source합니다. source하지 않으면 이 터미널은 새 패키지를 모르기 때문에 `echo`와 `message_subscriber`가 `Complex` 타입을 찾지 못합니다.

```bash
source ~/rosbook_ws/install/setup.bash
ros2 topic list -t
ros2 topic echo /complex --once
ros2 run basics message_subscriber
```

**관찰**: `/complex [basics_interfaces/msg/Complex]`가 보이고, `echo`는 `real: 0.52...`, `imaginary: 0.52...`를 보여 줍니다. subscriber는 `[INFO] [...] [message_subscriber]: real: 0.524, imaginary: 0.522`처럼 찍습니다. `echo`가 처음 보는 타입도 해석할 수 있는 것은 source 한 overlay에서 `basics_interfaces`를 찾기 때문입니다.

**생각해 볼 질문**: 원서 p.67이 다루는 질문처럼, 언제 새 메시지를 정의하고 언제 기존 메시지를 쓰는 것이 좋을까요? `geometry_msgs`나 `sensor_msgs`에 이미 있는 타입으로 충분한 경우를 떠올려 보세요.

### 실습 3-7. 받아서 다시 보내는 노드 (doubler)

**준비**: 터미널 3개.

**직접 입력**: 파일 `~/rosbook_ws/src/basics/basics/doubler.py`

```python
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import Int32


class Doubler(Node):
    def __init__(self):
        super().__init__('doubler')
        self.pub = self.create_publisher(Int32, 'doubled', 10)
        self.sub = self.create_subscription(
            Int32, 'number', self.callback, 10)

    def callback(self, msg):
        doubled = Int32()
        doubled.data = msg.data * 2
        self.pub.publish(doubled)


def main(args=None):
    rclpy.init(args=args)
    node = Doubler()
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

| 줄 | 설명 |
|---|---|
| 10 | `doubled` 토픽 publisher를 먼저 만듭니다. 콜백에서 이 publisher를 쓰므로, 콜백이 불릴 수 있게 되기 전에 준비해 둡니다. |
| 11~12 | `number` 토픽을 구독합니다. |
| 14~17 | 받은 값의 두 배를 새 메시지에 담아 `doubled`로 발행합니다. 받은 `msg` 객체를 고쳐서 다시 보내지 않고 새 객체를 만듭니다. |

`setup.py`에 `'doubler = basics.doubler:main',`을 등록하고(실습 3-6의 전체 파일 참고) 다시 빌드합니다.

터미널 A:

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics
source ~/rosbook_ws/install/setup.bash
ros2 run basics doubler
```

터미널 B:

```bash
ros2 topic echo /doubled
```

터미널 C:

```bash
ros2 topic pub -t 3 /number std_msgs/msg/Int32 "{data: 21}"
ros2 node info /doubler
```

**관찰**: 터미널 B에 `data: 42`가 찍힙니다. `-t 3`은 3번 발행하고 끝내라는 뜻인데, 맨 처음 것은 연결이 맺어지기 전에 나가서 빠질 수 있습니다. `node info`에는 `Subscribers:`에 `/number: std_msgs/msg/Int32`, `Publishers:`에 `/doubled: std_msgs/msg/Int32`가 보입니다.

이번에는 코드를 고치지 않고 실습 3-1의 publisher에 연결합니다. 터미널 A의 doubler를 끄고 다음처럼 띄운 뒤, 터미널 C에서 `ros2 run basics topic_publisher`를 실행합니다.

```bash
ros2 run basics doubler --ros-args -r number:=counter
```

터미널 B에 `12`, `14`, `16`처럼 짝수가 이어집니다. 노드를 재사용 가능한 부품으로 만들고 이름은 실행할 때 맞춘다는 2장의 리매핑이 여기서 쓰입니다.

**생각해 볼 질문**: doubler를 두 개 이어서 `/counter`를 네 배로 만들려면 두 번째 doubler를 어떻게 리매핑해야 할까요?

## 4. 일부러 망가뜨려 보기

| 바꿀 것 | 예상 증상 | 원인을 확인하는 명령 |
|---|---|---|
| `topic_publisher`가 도는 중에 `ros2 topic pub -r 1 /counter std_msgs/msg/String "{data: hi}"` (타입 불일치) | `topic_subscriber`는 오류 없이 정수만 계속 받습니다. 문자열 메시지는 조용히 무시됩니다. | `ros2 topic list -t`가 `/counter [std_msgs/msg/Int32, std_msgs/msg/String]`을 보여 줍니다. `ros2 topic info /counter`의 Type에도 두 타입이 나오고 Publisher count가 2입니다. |
| `ros2 run basics topic_subscriber --ros-args -r counter:=countr` (이름 오타) | 아무것도 받지 못하고, 오류도 없습니다. | `ros2 topic info /countr`: Publisher count 0, Subscription count 1 |
| publisher를 Ctrl-C로 종료 | subscriber는 종료되지 않고 기다립니다. publisher를 다시 띄우면 0부터 다시 받습니다. | `ros2 node list` |
| `ros2 topic pub -r 2 /counter std_msgs/msg/Int32 "{data: 7}" --qos-reliability best_effort` (QoS 불일치) | `topic_subscriber`에 `offering incompatible QoS ... Last incompatible policy: RELIABILITY` 경고가 나오고 7을 받지 못합니다. | `ros2 topic info -v /counter`로 양쪽 Reliability를 비교합니다. |
| `ros2 run basics topic_publisher --ros-args -p use_sim_time:=true` (시뮬레이션 시계 없이 시뮬레이션 시간 사용) | `/counter`에 아무것도 발행되지 않습니다. 시뮬레이션 시간이 0에서 멈춰 있어서 타이머가 만료되지 않습니다. | `ros2 param get /topic_publisher use_sim_time`이 `Boolean value is: True`. `ros2 topic info /clock`: Publisher count 0, Subscription count 1. 반대로 Gazebo 같은 시뮬레이터를 쓰면서 이 값을 빼먹으면 시각이 맞지 않는 문제가 생기며, 시뮬레이션 장에서 다룹니다. |
| `ros2 topic pub --once /counter std_msgs/msg/Int32 "{data: 2147483648}"` (범위 초과) | 오류 없이 `-2147483648`로 바뀌어 전달됩니다. | `ROS_PYTHON_CHECK_FIELDS=1`로 같은 값을 Python에서 대입해 보면 `AssertionError`가 납니다. |
| `basics_interfaces/package.xml`에서 `<member_of_group>` 줄을 지우고 빌드 | 빌드가 실패합니다. | `colcon build` 출력의 CMake 오류 메시지를 읽습니다. |

## 5. 확인 질문

<details><summary>Q1. 타이머를 self.timer에 붙잡아 두지 않으면 어떻게 되나요?</summary>

`create_timer`가 돌려준 타이머 객체를 아무도 참조하지 않으면 Python이 그 객체를 정리할 수 있고, 그러면 타이머가 동작하지 않거나 예상과 다르게 동작할 수 있습니다. publisher, subscriber, 타이머는 모두 `self.`에 붙잡아 두는 것이 안전한 습관입니다. 이 동작은 이 가이드에서 따로 실험하지 않았습니다.

</details>

<details><summary>Q2. publisher를 껐다 다시 켜면 subscriber는 어떻게 되나요?</summary>

subscriber는 publisher가 사라져도 종료되지 않고 같은 토픽을 계속 기다립니다. publisher가 다시 뜨면 디스커버리로 다시 연결되어 메시지를 받습니다. 다시 켠 publisher는 `self.count = 0`부터 시작하므로 0부터 찍힙니다.

</details>

<details><summary>Q3. TRANSIENT_LOCAL 토픽은 어디에 좋고 어디에 나쁜가요?</summary>

지도, 로봇 모델, 고정 좌표 변환처럼 드물게 바뀌지만 모든 노드가 알아야 하는 데이터에 좋습니다. 늦게 뜬 노드도 바로 최신 값을 받기 때문입니다. 센서 데이터처럼 계속 새로 오는 데이터에 쓰면, 늦게 접속한 노드가 이미 낡은 값을 먼저 받게 되고 depth가 크면 publisher가 그만큼 메모리를 씁니다.

</details>

<details><summary>Q4. BEST_EFFORT로 발행하는 카메라 토픽을 받으려면 QoS를 무엇으로 하나요?</summary>

subscriber도 BEST_EFFORT로 요청해야 합니다. RELIABLE로 요청하면 publisher가 그보다 약한 것을 내놓으므로 연결되지 않습니다. rclpy에는 이런 용도의 `qos_profile_sensor_data`가 미리 정의되어 있습니다.

</details>

<details><summary>Q5. 원서처럼 Complex.msg를 basics 패키지에 두면 무엇이 문제인가요?</summary>

`basics`는 `ament_python` 패키지라서 CMake를 쓰지 않고, `rosidl_generate_interfaces`로 메시지 코드를 생성할 수 없습니다. 그래서 메시지는 `ament_cmake` 패키지에서 정의해야 합니다. 또 메시지를 따로 두면, 다른 패키지(예를 들어 C++ 노드)가 노드 코드 없이 메시지만 의존할 수 있습니다.

</details>

<details><summary>Q6. 새 메시지는 언제 정의하나요?</summary>

같은 의미의 표준 메시지가 이미 있으면 그것을 씁니다. 위치와 방향은 `geometry_msgs`, 센서 값은 `sensor_msgs`처럼 표준 타입을 쓰면 rviz2 같은 기존 도구가 바로 이해합니다. 표준 타입으로 표현할 수 없는, 그 프로젝트에만 의미가 있는 묶음일 때 새로 정의합니다.

</details>

<details><summary>Q7. doubler 두 개로 /counter를 네 배로 만들려면 어떻게 하나요?</summary>

첫 번째는 `--ros-args -r number:=counter`로 `/counter`를 받아 `/doubled`로 내보냅니다. 두 번째는 이름이 겹치지 않게 노드 이름을 바꾸고, 입력을 첫 번째의 출력으로, 출력을 새 이름으로 리매핑합니다. 예: `--ros-args -r __node:=doubler2 -r number:=doubled -r doubled:=quadrupled`. 그러면 `/quadrupled`에 네 배 값이 나옵니다.

</details>

## 6. 원서 대조 메모

- 원서 p.52~56의 publisher 예제는 노드 이름 하나와 전역 함수 호출로 짜여 있습니다. 이 가이드는 CONVENTIONS의 rclpy 골격(Node 상속, 타이머, `try_shutdown`)으로 다시 썼고, 원서 코드를 옮기지 않았습니다. 원서 예제의 Publisher 생성에는 `queue_size`가 없어서 당시 rospy가 경고를 냈습니다. ROS 2는 QoS(depth)를 반드시 넘겨야 합니다.
- 원서 p.53의 의존성 표기 `<depend package="std_msgs" />`는 rosbuild 시절의 `manifest.xml` 형식입니다. catkin의 `package.xml`에서도 ROS 2의 format 3에서도 `<depend>std_msgs</depend>`로 씁니다.
- 원서 p.59의 latched 예제는 인자 이름이 `latched=True`로 적혀 있지만 rospy의 실제 인자 이름은 `latch=True`입니다. 같은 예제에서 타입 자리에 클래스 대신 `nav_msgs/OccupancyGrid`라는 문자열 형태가 쓰였습니다.
- 원서 p.58~59의 latched 토픽은 subscriber 쪽에서 아무 설정도 하지 않아도 마지막 메시지를 받았습니다. ROS 2에서는 subscriber도 TRANSIENT_LOCAL로 요청해야 하고, 이 PC에서는 reliability까지 맞춰야 받았습니다 (실습 3-3).
- 원서 p.60은 Python에서 범위를 넘는 값을 넣으면 직렬화할 때 문제가 드러난다고 설명합니다. Jazzy rclpy는 기본 설정에서 대입도 발행도 오류 없이 통과시키고 값이 잘려 전달됩니다. `ROS_PYTHON_CHECK_FIELDS=1`이면 대입할 때 `AssertionError`가 납니다.
- 원서 p.61~65는 `Complex.msg`를 `basics` 패키지에 두고 `message_generation`을 씁니다. ROS 2에서는 별도 `ament_cmake` 패키지 `basics_interfaces`와 `rosidl_default_generators`를 씁니다. 패키지 이름이 달라지므로 import 문도 `from basics_interfaces.msg import Complex`가 됩니다.
- 원서 p.68의 doubler 예제는 subscriber를 publisher보다 먼저 만듭니다. rospy는 콜백을 별도 스레드에서 부르므로, 그 사이에 메시지가 도착하면 아직 없는 publisher를 쓰려다 오류가 날 수 있습니다. 이 가이드는 publisher를 먼저 만듭니다. rclpy는 `spin` 전에는 콜백을 부르지 않아서 순서 문제가 드러나지 않지만, 습관으로 둡니다.
- 원서는 `std_msgs`의 단순 타입을 자유롭게 씁니다. ROS 2의 `std_msgs/msg/Int32` 정의에는 deprecated 안내 주석이 있습니다. 원서 흐름과 20장, 23장의 재사용 때문에 연습용으로 그대로 씁니다.

## 7. 이 문서의 검증 상태

- 확인함 (2026-10-27, WSL2 Ubuntu 24.04, ROS 2 Jazzy, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`, 검증용 `ROS_DOMAIN_ID=21`, `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`, 별도 검증 워크스페이스에 이 문서의 파일 그대로 작성):
  - `basics_interfaces`와 `basics` 빌드, `colcon test --packages-select basics` (3 tests, 0 errors, 0 failures, 1 skipped; flake8, pep257 통과).
  - `topic_publisher`: `topic list -t`, `topic echo --once`(`data: 9`), `topic hz`(average rate 2.000), `topic info -v`(RELIABLE, KEEP_LAST (10), VOLATILE), `topic find`.
  - `topic_subscriber` 수신, `topic pub --once`로 끼어든 `1000000` 수신, `2147483648` 발행 시 `-2147483648` 수신, `ROS_PYTHON_CHECK_FIELDS=1`일 때 `AssertionError` 문구, 기본 설정에서는 오류 없음.
  - `latched_publisher`: 늦게 띄운 `echo`가 옵션 없이, 그리고 `transient_local`+`reliable`로 `42`를 받음. `transient_local`만 준 경우, `volatile`, VOLATILE 구독자(`topic_subscriber` 리매핑)는 받지 못함.
  - QoS 조합 표 8가지 전부와 RELIABILITY, DURABILITY 경고 문구(양쪽).
  - `basics_interfaces` 생성 파일, `interface show`, `interface package`, 생성된 `_complex.py` 위치, `std_msgs/msg/Int32`의 deprecated 주석.
  - `message_publisher`/`message_subscriber` 송수신과 로그 형식.
  - `doubler`: `/number`에 21을 넣으면 `/doubled`에 42, `node info` 출력, `-r number:=counter`로 연결 시 짝수 출력.
  - 일부러 망가뜨리기 표 중 타입 불일치, 이름 오타, publisher 종료 후 subscriber 생존, QoS 불일치, `use_sim_time:=true` 시 발행 없음과 `/clock` 상태, 범위 초과.
- 확인 못 함:
  - `<member_of_group>` 줄을 지웠을 때의 빌드 실패와 그 오류 문구.
  - Q1의 타이머 객체를 붙잡지 않았을 때의 동작.
  - publisher를 다시 켰을 때 0부터 다시 받는 것은 코드에 근거한 설명이며 따로 실행해 보지 않았습니다.
  - 학습자의 `~/rosbook_ws`에서 장 순서대로 한 단계씩 빌드하는 과정 (검증은 최종 형태의 패키지로 했습니다). 기본 도메인 0에서의 실행.
