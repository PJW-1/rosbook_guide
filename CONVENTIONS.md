# 장 문서 규칙

이 파일은 모든 장 문서가 따르는 형식과 규칙을 정합니다. 학습자는 각 장이 어떤 순서로 구성되는지 확인하는 용도로 읽으면 되고, 장을 작성하는 사람은 아래 규칙을 반드시 지켜야 합니다.

## 1. 우선순위

1. ROS 2의 구조를 정확히 이해하고 체감하는 것이 첫째 목표입니다. 실습은 무엇이 어떤 이름과 타입으로 연결되는지가 눈에 보이도록 구성합니다.
2. 로봇이 원하는 대로 움직이는 것은 둘째 목표입니다. 실습이 실패하더라도 원인을 추적하면서 배울 수 있도록, 관찰 명령과 확인 방법을 함께 적습니다.
3. 학습자는 모든 명령과 코드를 직접 입력합니다. 한 번에 입력할 분량이 지나치게 길어지지 않도록 실습을 잘게 나눕니다.

## 2. 저작권 규칙

원서는 저작권이 있는 출판물입니다. 이 가이드는 번역본이 아니며, 다음 규칙을 지킵니다.

- 원서는 각 장에 어떤 목표, 개념, 실습이 있는지 확인하는 용도로만 읽습니다.
- 원서 문장을 번역하지 않습니다. 원서 문단의 순서를 따라가면서 표현만 바꿔 쓰는 것도 하지 않습니다. 설명은 처음부터 새로, 짧게 씁니다.
- 원서 문장을 인용하지 않습니다. 원서의 설명이 필요하면 "원서 PDF p.123"처럼 쪽 번호로 안내합니다.
- 원서의 rospy·roscpp 코드를 옮겨 적지 않습니다. 같은 목표를 이루는 ROS 2 코드를 새로 작성합니다. 파일 이름이나 토픽 이름처럼 실습을 원서와 대응시키는 데 필요한 이름은 원서와 같게 써도 됩니다.
- 원서의 그림과 표는 옮기지 않습니다. 필요하면 구조를 새로 그린 텍스트 다이어그램을 씁니다.

## 3. 장 문서 형식

파일 이름은 `chNN_<영문_슬러그>.md`입니다. (예: `ch07_wander_bot.md`)
아래 순서를 지키고, 해당 내용이 없는 절은 "해당 없음"이라고 한 줄로 적습니다.

````markdown
# N장. 한국어 제목

- 원서: Chapter N. English Title, PDF p.A~B (인쇄 쪽 = PDF 쪽 - 20)
- 선행 조건: 앞 장에서 만든 패키지, 미리 실행해 둘 것
- 새로 설치할 것: 없음 또는 `sudo apt install ...` (학습자가 직접 실행)

## 이 장에서 체감할 구조
3줄 이내로, 이 장을 마치면 머릿속에 남아야 할 연결 구조를 적습니다. 필요하면 텍스트 다이어그램을 붙입니다.

## 1. 목표와 개념
원서가 이 장에서 이루려는 목표와 필요한 개념만 짧게 새로 씁니다.

## 2. 원서(ROS 1)와 달라지는 점
| 원서 (ROS 1) | ROS 2 Jazzy | 이유와 주의점 |
|---|---|---|

## 3. 실습
### 실습 N-1. 제목
**준비**: 열어 둘 터미널과, 각 터미널에서 이미 실행 중이어야 하는 것
**직접 입력**: 명령 또는 코드 전체 (파일이면 전체 경로를 먼저 적음)
**줄 단위 해설**: 코드가 있을 때 `| 줄 | 설명 |` 표로 씁니다. 사소한 줄은 묶어도 됩니다.
**관찰**: 무엇을 보면 되는지, 출력이 어떤 모양이어야 하는지
**생각해 볼 질문**: 1~2개. 답은 5절에 둡니다.

## 4. 일부러 망가뜨려 보기
| 바꿀 것 | 예상 증상 | 원인을 확인하는 명령 |
|---|---|---|

## 5. 확인 질문
<details><summary>Q1. 질문</summary>

답

</details>

## 6. 원서 대조 메모
원서의 오류, ROS 1에만 있는 내용, ROS 2에서 생략하거나 바꾼 부분과 그 이유를 적습니다.

## 7. 이 문서의 검증 상태
- 확인함: 무엇을 어떤 방법으로 확인했는지
- 확인 못 함: 무엇이 남았는지
````

## 4. 공통 실습 환경

- Windows 11 + WSL2 Ubuntu 24.04, ROS 2 Jazzy (`/opt/ros/jazzy`), 실물 로봇 없이 시뮬레이션만 씁니다.
- 워크스페이스는 `~/rosbook_ws`이고, 패키지는 `~/rosbook_ws/src/` 아래에 만듭니다.
- `~/.bashrc`는 터미널을 열 때마다 `/opt/ros/jazzy/setup.bash`와 `~/rosbook_ws/install/setup.bash`를 source 하고, `TURTLEBOT3_MODEL=waffle_pi`를 설정합니다.
- 빌드 명령은 `cd ~/rosbook_ws && colcon build --symlink-install --packages-select <패키지>`입니다.
  새 패키지를 처음 빌드했거나 새 실행 파일을 추가했다면, 이미 열려 있던 터미널에서 `source ~/rosbook_ws/install/setup.bash`를 다시 실행해야 합니다.
- TurtleBot3 시뮬은 `ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py`로 띄웁니다.
- TurtleBot3 시뮬의 `/cmd_vel` 타입은 `geometry_msgs/msg/TwistStamped`입니다. 원서가 쓰는 `Twist`와 다릅니다.
- 시뮬 토픽을 다루는 노드와 rviz2, rqt 도구는 `use_sim_time:=true`로 실행합니다.

## 5. 패키지와 파일 이름

| 장 | 패키지 | 빌드 타입 | 비고 |
|---|---|---|---|
| 2~5, 20~21 | `basics` | ament_python | 원서의 basics 패키지에 대응합니다. 실행 파일 이름은 원서 스크립트 이름에서 `.py`를 뺀 것입니다. |
| 3~5 | `basics_interfaces` | ament_cmake | 3장에서 `msg/Complex.msg`, 4장에서 `srv/WordCount.srv`, 5장에서 `action/Timer.action`을 차례로 추가합니다. |
| 7 | `wander_bot` | ament_python | |
| 8 | `teleop_bot` | ament_python | |
| 9~10 | `nav_bot` | ament_python | 지도 파일은 `~/rosbook_ws/maps/`에 저장합니다. |
| 11 | `chess_bot` | ament_python | |
| 12 | `follow_bot` | ament_python | |
| 13 | `patrol` | ament_python | |
| 14 | `stockroom_bot` | ament_python | |
| 15 | `sensors_actuators` | ament_python | |
| 16~17 | `tortoisebot` | 작성자가 결정 | |
| 18 | `cougarbot`, `cougarbot_moveit_config` | 작성자가 결정 | |
| 19 | `talk_bot` | ament_python | |
| 23 | `basics_cpp` | ament_cmake | |

`basics_interfaces`의 기본 형태는 다음과 같습니다. 3장에서 만들고 4장과 5장에서 확장합니다.

- 생성 명령: `ros2 pkg create --build-type ament_cmake --license Apache-2.0 basics_interfaces`
- `package.xml`: `<buildtool_depend>rosidl_default_generators</buildtool_depend>`, `<exec_depend>rosidl_default_runtime</exec_depend>`, `<member_of_group>rosidl_interface_packages</member_of_group>`를 추가합니다. 액션에 필요한 추가 의존성은 5장에서 빌드로 확인한 뒤에 적습니다.
- `CMakeLists.txt`: `find_package(rosidl_default_generators REQUIRED)`와 `rosidl_generate_interfaces(${PROJECT_NAME} "msg/Complex.msg" ...)`를 씁니다. 4장과 5장은 이 목록에 파일을 한 줄씩 추가합니다.

## 6. rclpy 코드 기본 형태

모든 장의 Python 노드는 아래 형태를 기본으로 씁니다. 장마다 다른 형태를 쓰면 학습자가 무엇이 본질이고 무엇이 취향인지 구분하기 어려워지기 때문입니다.

```python
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node


class MyNode(Node):
    def __init__(self):
        super().__init__('my_node')
        # publisher, subscription, timer, parameter 선언


def main(args=None):
    rclpy.init(args=args)
    node = MyNode()
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

- 현재 시각은 `self.get_clock().now()`로 얻습니다. `use_sim_time:=true`로 실행하면 이 값이 `/clock`을 따릅니다.
- 로그는 `self.get_logger().info()` 계열을 씁니다. `print()`를 쓰지 않는 이유는 21장에서 다룹니다.
- 실행 파일은 `setup.py`의 `entry_points['console_scripts']`에 등록합니다.

## 7. 문체

- 한국어 합니다체로 씁니다. 문장은 서술어로 끝맺고, 조사를 생략하지 않습니다.
- 엠대시(—)를 쓰지 않습니다. 콜론이나 접속사로 문장 관계를 드러냅니다.
- ROS 용어는 정착된 표기를 그대로 씁니다 (노드, 토픽, 메시지 타입, QoS, publisher, subscriber 등). 처음 나올 때 한 번 짧게 풀이합니다.
- 비유가 도움이 되는 개념은 "비유:"로 시작하는 한 줄로 따로 적습니다. 본문 설명은 일반적인 용어로 씁니다.
- 코드 안의 주석은 꼭 필요한 곳에만 짧게 쓰고, 설명은 코드 아래 줄 단위 해설 표에 씁니다.
