# 9장. 지도 만들기

- 원서: Chapter 9. Building Maps of the World, PDF p.155~170 (인쇄 쪽 = PDF 쪽 - 20)
- 선행 조건: 6장(TurtleBot3 시뮬 띄우기), 8장(`teleop_twist_keyboard`를 `stamped:=true`로 쓰기, rviz2 기본 조작)
- 새로 설치할 것: 없음. `ros-jazzy-slam-toolbox`, `ros-jazzy-nav2-map-server`, `ros-jazzy-turtlebot3-navigation2`가 이미 설치되어 있어야 합니다. `apt-cache policy ros-jazzy-slam-toolbox ros-jazzy-nav2-map-server`로 `Installed:` 줄을 확인합니다.

## 이 장에서 체감할 구조

지도는 `/map` 토픽 위의 `nav_msgs/msg/OccupancyGrid` 메시지 하나이고, 늦게 들어온 subscriber도 받도록 `transient_local`로 발행됩니다.
SLAM 노드는 `/scan`과 tf를 받아 `/map`과 `map → odom` 변환을 만들고, `map_server`는 저장된 파일로 같은 `/map`을 다시 만들어 냅니다. 둘 다 lifecycle 노드입니다.

```
[Gazebo] ─ ros_gz_bridge ─┬─ /scan (LaserScan) ──────────────┐
                          └─ /tf  odom → base_footprint ─────┤
robot_state_publisher ── /tf_static base_footprint → base_link → base_scan
                                                             ▼
                                         slam_toolbox ── /map (transient_local)
                                                      └─ /tf  map → odom
/map ── map_saver_cli ──▶ tb3_world.yaml + tb3_world.pgm ──▶ map_server ── /map
```

## 1. 목표와 개념

원서 9장의 목표는 로봇 센서 데이터로 2D 지도를 만들고, 파일로 저장했다가 다시 ROS에 띄우는 것입니다. 이 지도는 10장의 위치 추정과 경로 계획에 그대로 쓰입니다.

**OccupancyGrid**: 바닥을 일정한 크기의 정사각형 칸(cell)으로 나누고, 칸마다 "막혀 있는지"를 숫자로 적은 지도입니다. ROS 2 메시지에서는 칸 하나가 `int8` 값 하나이고, 보통 0은 비어 있음, 100은 막혀 있음, -1은 모름을 뜻합니다. 칸들은 `data` 배열에 한 줄로 들어 있고, 지도 왼쪽 아래 칸 (0, 0)부터 x 방향으로 먼저 채웁니다. 그래서 (열 `col`, 행 `row`) 칸의 값은 `data[row * width + col]`입니다.

**지도 파일 두 개**: 디스크에서는 지도 한 장이 이미지 파일(PGM)과 YAML 파일 한 쌍입니다. 이미지에는 칸의 밝기가, YAML에는 칸 하나의 크기(`resolution`, m/칸), 이미지 왼쪽 아래 칸이 세계 좌표 어디에 있는지(`origin`), 밝기를 점유 확률로 바꾸는 기준(`occupied_thresh`, `free_thresh`, `negate`)이 들어 있습니다.

`negate: 0`일 때 Nav2 map_server는 밝기 `v`(0~255)를 `p = (255 - v) / 255`로 바꾼 뒤, `p > occupied_thresh`이면 100, `p < free_thresh`이면 0, 그 사이면 -1로 정합니다 (`mode: trinary`). 검은색(0)은 p=1이라 막힘, 흰색(254)은 p≈0이라 비어 있음, 회색(205)은 p≈0.196이라 모름이 됩니다. 이미지는 위쪽 줄부터 저장되지만 지도의 행 번호는 아래쪽부터 세므로, map_server가 읽을 때 위아래를 뒤집습니다.

**SLAM**: 지도를 만들려면 로봇 위치를 알아야 하고, 위치를 정확히 알려면 지도가 필요합니다. 이 둘을 동시에 추정하는 것이 SLAM(Simultaneous Localization and Mapping)입니다. 이 장에서는 slam_toolbox를 씁니다.

**map → odom**: 오도메트리(`odom → base_footprint`)는 바퀴 회전으로 위치를 적분하므로 시간이 지나면 조금씩 어긋납니다. SLAM 노드는 레이저 스캔을 지도와 맞춰 보고, 그 어긋남을 고치는 변환을 `map → odom`으로 발행합니다. 오도메트리 쪽 tf는 건드리지 않고 그 위에 보정 한 단계를 얹는 구조입니다.

비유: `odom`은 걸음 수로 잰 내 위치이고, `map → odom`은 건물 안내도를 보고 "실제로는 여기서 조금 옆이다"라고 고쳐 주는 쪽지입니다.

**bag**: 토픽에 흐르는 메시지를 시각과 함께 파일에 기록했다가 나중에 똑같이 다시 발행하는 도구입니다. 같은 센서 데이터로 SLAM 파라미터를 여러 번 바꿔 볼 수 있어서, 원서도 지도를 만들기 전에 bag을 먼저 소개합니다 (원서 PDF p.158~160).

**lifecycle 노드**: Nav2의 map_server는 실행하자마자 일을 시작하지 않습니다. `unconfigured → (configure) → inactive → (activate) → active` 순서로 상태를 바꿔 줘야 `/map`을 발행합니다. 여러 노드를 정해진 순서로 준비시키고, 문제가 생기면 한꺼번에 멈추기 위한 ROS 2의 구조입니다. 이 장의 실습 9-3에서 이 전환을 손으로 직접 해 봅니다.

## 2. 원서(ROS 1)와 달라지는 점

| 원서 (ROS 1) | ROS 2 Jazzy | 이유와 주의점 |
|---|---|---|
| `slam_gmapping` (gmapping) | `slam_toolbox` 2.8.5 (`async_slam_toolbox_node`, `sync_slam_toolbox_node`) | gmapping은 ROS 2용 공식 배포가 없습니다. slam_toolbox는 Nav2 문서가 기본으로 쓰는 SLAM입니다. 아래 "SLAM 도구 선택" 참고 |
| `rosrun map_server map_server map.yaml` | `ros2 run nav2_map_server map_server --ros-args -p yaml_filename:=...` 뒤에 configure, activate | map_server가 lifecycle 노드가 되었습니다. 파일 경로는 인자가 아니라 파라미터로 줍니다 |
| `rosrun map_server map_saver` | `ros2 run nav2_map_server map_saver_cli -f <이름>` | `-f`로 파일 이름(확장자 제외)을 정합니다 |
| `/map`, `/map_metadata` 토픽 | `/map` 토픽 (QoS: reliable, transient_local, depth 1) | ROS 1의 latched 토픽이 ROS 2에서는 QoS durability `transient_local`입니다 |
| `rosbag record -O data.bag scan tf` | `ros2 bag record -o tb3_drive /scan /tf /tf_static /odom` | 결과가 파일 하나가 아니라 폴더(`metadata.yaml` + `.mcap`)입니다. Jazzy 기본 저장 형식은 MCAP입니다. ROS 2는 고정 변환을 `/tf_static`에 따로 내므로 반드시 함께 기록합니다 |
| `rosbag play --clock data.bag` | `ros2 bag play tb3_drive --clock` | Jazzy에서 `--clock`은 뒤에 Hz 값을 받을 수 있는 옵션이라, `--clock tb3_drive` 순서로 쓰면 bag 경로를 숫자로 읽으려다 오류가 납니다. 경로를 먼저 씁니다 |
| `rosparam set use_sim_time true` (전역) | 노드마다 `-p use_sim_time:=true` 또는 launch 인자 | ROS 2에는 전역 파라미터 서버가 없습니다 |
| Stage 시뮬레이터, TurtleBot 2 (Kinect로 만든 가짜 LaserScan) | Gazebo + TurtleBot3 waffle_pi (360° LiDAR) | 원서가 지도 품질이 나쁜 이유로 든 좁은 시야각 문제(원서 PDF p.166)가 TurtleBot3에는 덜합니다 |
| `/cmd_vel`: `Twist` | `/cmd_vel`: `TwistStamped` | 텔레옵을 `stamped:=true`로 실행해야 로봇이 움직입니다 |

**SLAM 도구 선택**: 설치된 패키지 중 지도를 만들 수 있는 것은 `slam_toolbox`와 ROBOTIS의 `turtlebot3_cartographer`(Cartographer 사용) 두 가지입니다. 이 가이드는 slam_toolbox를 중심으로 씁니다. 이유는 세 가지입니다.

1. 설치된 slam_toolbox 2.8.5의 `online_async_launch.py`는 노드를 `LifecycleNode`로 띄우고 launch 안에서 configure와 activate를 자동으로 보냅니다. map_server와 같은 lifecycle 구조라서 이 장의 핵심 개념을 두 번 확인할 수 있습니다.
2. 실시간 지도 작성(online)과 bag 재생으로 만드는 방식(`online_sync_launch.py`, `offline_launch.py`)이 같은 패키지 안에 있어서, 원서의 "bag으로 지도 만들기" 흐름을 그대로 따라갈 수 있습니다.
3. 10장의 Nav2(`nav2_bringup`)도 SLAM 모드에서 slam_toolbox를 씁니다 (`nav2_bringup/launch/slam_launch.py`).

Cartographer를 쓰려면 `ros2 launch turtlebot3_cartographer cartographer.launch.py use_sim_time:=True`입니다. 이 launch 파일은 `use_sim_time` 기본값이 `false`이고 rviz2를 함께 띄웁니다(`use_rviz` 기본값 `true`). 비교해 보고 싶을 때만 써 보세요.

## 3. 실습

### 실습 9-1. 지도 파일을 손으로 만들어 보기

**준비**: 터미널 1개. 시뮬레이터는 필요 없습니다.

**직접 입력**: 가로 10칸, 세로 6칸짜리 아주 작은 지도를 만듭니다. 테두리는 벽(검정 0), 안쪽은 빈 공간(흰색 254), 이미지 오른쪽 위 2×2칸은 모름(회색 205)입니다.

```bash
mkdir -p ~/rosbook_ws/maps
cd ~/rosbook_ws/maps
```

파일 `~/rosbook_ws/maps/make_tiny_map.py`:

```python
width, height = 10, 6
pixels = []
for y in range(height):
    for x in range(width):
        if x in (0, width - 1) or y in (0, height - 1):
            pixels.append(0)
        elif x >= 7 and y <= 2:
            pixels.append(205)
        else:
            pixels.append(254)

with open('tiny.pgm', 'wb') as f:
    f.write(b'P5\n%d %d\n255\n' % (width, height))
    f.write(bytes(pixels))
```

| 줄 | 설명 |
|---|---|
| 1 | 이미지 크기를 칸 단위로 정합니다. 지도에서는 픽셀 하나가 칸 하나입니다 |
| 3~10 | 이미지의 위쪽 줄(y=0)부터 왼쪽에서 오른쪽으로 밝기를 하나씩 정합니다. 테두리는 0, 오른쪽 위 구석은 205, 나머지는 254입니다 |
| 12~14 | PGM 바이너리 형식(`P5`)으로 저장합니다. 머리글에 너비, 높이, 최대 밝기(255)를 적고 그 뒤에 픽셀 바이트를 이어 붙입니다 |

파일 `~/rosbook_ws/maps/tiny.yaml`:

```yaml
image: tiny.pgm
mode: trinary
resolution: 0.5
origin: [-1.0, -1.0, 0.0]
negate: 0
occupied_thresh: 0.65
free_thresh: 0.196
```

```bash
python3 make_tiny_map.py
ls -l tiny.*
head -c 11 tiny.pgm | od -c
```

| 줄 | 설명 |
|---|---|
| `image` | 이미지 파일 경로입니다. 상대 경로면 YAML 파일이 있는 폴더 기준입니다 |
| `mode` | `trinary`는 칸을 0, 100, -1 세 값 중 하나로 바꿉니다 |
| `resolution` | 칸 한 변의 길이(m)입니다. 이 지도는 5 m × 3 m가 됩니다 |
| `origin` | 이미지 왼쪽 아래 칸의 모서리가 세계 좌표 (x, y, yaw)로 어디인지 적습니다 |
| `negate` | 1로 바꾸면 밝은 색을 막힘으로 해석합니다 |
| `occupied_thresh`, `free_thresh` | 1절의 식에서 막힘과 비어 있음을 가르는 기준입니다 |

**관찰**: `tiny.pgm`은 72바이트입니다 (머리글 12바이트 + 픽셀 60개). `od -c` 출력 첫 부분에 `P 5 \n 1 0 6 \n`이 보입니다. 이미지 뷰어 없이도 지도 파일이 "숫자가 든 이미지 + 설명서"라는 것을 확인할 수 있습니다.

**생각해 볼 질문**: 회색 205는 1절의 식으로 p가 얼마이고, 이 YAML에서는 0, 100, -1 중 어느 값이 될까요?

### 실습 9-2. `nav_bot` 패키지와 지도 읽기 노드 만들기

**준비**: 터미널 1개.

**직접 입력**: 9장과 10장에서 함께 쓸 `nav_bot` 패키지를 만듭니다. 10장에서 쓸 의존성도 지금 한꺼번에 적습니다. `--dependencies`는 뒤에 오는 단어를 모두 의존성으로 읽으므로 패키지 이름을 앞에 씁니다.

```bash
cd ~/rosbook_ws/src
ros2 pkg create nav_bot --build-type ament_python --license Apache-2.0 \
  --dependencies rclpy action_msgs geometry_msgs nav_msgs nav2_msgs nav2_simple_commander
```

생성된 `~/rosbook_ws/src/nav_bot/package.xml`에 다음 줄들이 들어 있는지 확인합니다. 손으로 추가할 것은 없습니다.

```xml
  <depend>rclpy</depend>
  <depend>action_msgs</depend>
  <depend>geometry_msgs</depend>
  <depend>nav_msgs</depend>
  <depend>nav2_msgs</depend>
  <depend>nav2_simple_commander</depend>
```

파일 `~/rosbook_ws/src/nav_bot/nav_bot/map_info.py`:

```python
from nav_msgs.msg import OccupancyGrid
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from rclpy.qos import DurabilityPolicy, QoSProfile, ReliabilityPolicy


class MapInfo(Node):
    def __init__(self):
        super().__init__('map_info')
        self.declare_parameter('x', 0.0)
        self.declare_parameter('y', 0.0)
        qos = QoSProfile(
            depth=1,
            reliability=ReliabilityPolicy.RELIABLE,
            durability=DurabilityPolicy.TRANSIENT_LOCAL,
        )
        self.create_subscription(OccupancyGrid, 'map', self.on_map, qos)
        self.get_logger().info('/map 을 기다립니다')

    def on_map(self, msg):
        info = msg.info
        free = msg.data.count(0)
        occupied = msg.data.count(100)
        unknown = msg.data.count(-1)
        self.get_logger().info(
            f'frame={msg.header.frame_id} '
            f'size={info.width}x{info.height} cells, '
            f'resolution={info.resolution:.3f} m/cell, '
            f'origin=({info.origin.position.x:.2f}, {info.origin.position.y:.2f})')
        self.get_logger().info(
            f'free={free} occupied={occupied} unknown={unknown}')

        x = self.get_parameter('x').value
        y = self.get_parameter('y').value
        col = int((x - info.origin.position.x) / info.resolution)
        row = int((y - info.origin.position.y) / info.resolution)
        if 0 <= col < info.width and 0 <= row < info.height:
            value = msg.data[row * info.width + col]
            self.get_logger().info(
                f'({x:.2f}, {y:.2f}) -> cell (col={col}, row={row}) = {value}')
        else:
            self.get_logger().info(f'({x:.2f}, {y:.2f}) 는 지도 밖입니다')


def main(args=None):
    rclpy.init(args=args)
    node = MapInfo()
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
| 1~5 | 지도 메시지 타입과 QoS 설정용 클래스를 가져옵니다. import 순서는 ament_flake8 검사 규칙(모듈 이름 알파벳 순)에 맞춘 것입니다 |
| 11~12 | 값을 확인할 세계 좌표 (x, y)를 파라미터로 받습니다. 기본값이 `0.0`이므로 실수 타입 파라미터가 됩니다 |
| 13~17 | subscriber의 QoS입니다. `TRANSIENT_LOCAL`은 "내가 늦게 접속해도 publisher가 보관 중인 마지막 메시지를 달라"는 요청입니다. map_server와 slam_toolbox가 `/map`을 이 설정으로 내기 때문에 맞춰야 합니다 |
| 18 | `map` 토픽을 구독합니다. 이름 앞에 `/`가 없으므로 노드 namespace를 따르며, 지금은 `/map`이 됩니다 |
| 22~25 | `data`는 칸 값이 한 줄로 든 배열입니다. 0, 100, -1의 개수를 셉니다 |
| 26~32 | 지도 크기, 해상도, 원점, frame을 출력합니다. YAML에 적은 값과 비교하는 용도입니다 |
| 34~37 | 세계 좌표를 칸 번호로 바꿉니다. 원점을 빼고 해상도로 나눈 뒤 정수로 자릅니다 |
| 38~44 | 1절의 `data[row * width + col]` 식으로 그 칸의 값을 꺼냅니다 |
| 47~59 | CONVENTIONS의 기본 `main` 형태입니다 |

파일 `~/rosbook_ws/src/nav_bot/setup.py`의 `entry_points` 부분을 다음처럼 고칩니다. 10장에서 쓸 실행 파일은 그때 한 줄씩 추가합니다.

```python
    entry_points={
        'console_scripts': [
            'map_info = nav_bot.map_info:main',
        ],
    },
```

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select nav_bot
source ~/rosbook_ws/install/setup.bash
ros2 pkg executables nav_bot
```

**관찰**: 마지막 명령이 `nav_bot map_info`를 출력하면 됩니다. 아직 `/map`을 내는 노드가 없으므로 실행은 다음 실습에서 합니다.

**생각해 볼 질문**: 이 노드는 `/map`을 내는 노드 이름을 코드 어디에도 적지 않았습니다. 그런데도 다음 실습에서 map_server의 지도를 받을 수 있는 이유는 무엇일까요?

### 실습 9-3. map_server를 lifecycle 명령으로 직접 깨우기

**준비**: 터미널 3개. 시뮬레이터는 필요 없습니다. 이 실습만 할 때는 Gazebo를 꺼 둡니다.

**직접 입력**:

터미널 1: map_server를 실행합니다.

```bash
ros2 run nav2_map_server map_server --ros-args -p yaml_filename:=$HOME/rosbook_ws/maps/tiny.yaml
```

터미널 2: 지도 읽기 노드를 먼저 띄워 둡니다.

```bash
ros2 run nav_bot map_info --ros-args -p x:=3.0 -p y:=0.5
```

터미널 3: 상태를 확인하면서 한 단계씩 전환합니다.

```bash
ros2 lifecycle nodes
ros2 lifecycle get /map_server
ros2 lifecycle list /map_server
ros2 topic list
```

```bash
ros2 lifecycle set /map_server configure
ros2 lifecycle get /map_server
ros2 topic info -v /map
```

```bash
ros2 lifecycle set /map_server activate
ros2 lifecycle get /map_server
```

```bash
ros2 topic echo /map --once --no-arr
ros2 service list | grep map_server
ros2 node info /map_server
```

**관찰**:

- 터미널 1에는 실행 직후 `Waiting on external lifecycle transitions to activate`가 찍힙니다. 처음 `ros2 lifecycle get /map_server`는 `unconfigured [1]`입니다. `ros2 lifecycle list`는 지금 가능한 전환(configure, shutdown 계열)을 보여 줍니다. `ros2 topic list`에는 아직 `/map`이 없습니다.
- `configure` 뒤에는 `Transitioning successful`이 나오고 `inactive [2]`가 됩니다. 터미널 1에 `Loading yaml file`, YAML의 각 값, `Read map ...: 10 X 6 map @ 0.5 m/cell` 로그가 찍힙니다. 이때 `ros2 topic info -v /map`을 보면 publisher가 이미 1개 있고 QoS가 `Reliability: RELIABLE`, `History (Depth): KEEP_LAST (1)`, `Durability: TRANSIENT_LOCAL`입니다. 그런데 터미널 2의 map_info는 아직 아무것도 받지 못합니다. 파일을 읽고 publisher를 만들어 두기만 했고, 발행은 하지 않은 상태입니다.
- `activate` 뒤에는 `active [3]`가 되고, 터미널 2에 다음과 비슷한 줄이 바로 찍힙니다.

  ```
  frame=map size=10x6 cells, resolution=0.500 m/cell, origin=(-1.00, -1.00)
  free=28 occupied=28 unknown=4
  (3.00, 0.50) -> cell (col=8, row=3) = -1
  ```

  (3.0, 0.5)는 지도 오른쪽 위입니다. 9-1에서 이미지 오른쪽 "위" 구석을 회색으로 칠했는데, 지도에서도 y가 큰 쪽(위)에 -1로 나타납니다. map_server가 이미지의 위아래를 뒤집어 읽기 때문에 사람이 보는 그림과 지도 좌표가 같은 방향이 됩니다.
- `ros2 service list`에는 `/map_server/change_state`, `/map_server/get_state` 같은 lifecycle 서비스가 보입니다. `ros2 lifecycle set`은 이 서비스를 호출하는 도구일 뿐입니다. `/map_server/map`(지도를 서비스로 받는 `nav_msgs/srv/GetMap`)과 `/map_server/load_map`(다른 지도로 바꾸기)도 있습니다.

이제 map_info를 Ctrl-C로 끄고 **activate 이후에** 다시 실행합니다.

```bash
ros2 run nav_bot map_info --ros-args -p x:=2.0 -p y:=1.0 -r __node:=map_info_late
```

map_server는 지도를 activate 순간에 한 번만 발행했는데도, 늦게 온 노드가 지도를 바로 받습니다. 이것이 `transient_local`입니다.

마지막으로 터미널 3에서 `ros2 lifecycle set /map_server deactivate`를 실행하고 `ros2 topic info /map`을 봅니다. 상태는 `inactive [2]`로 돌아가지만 publisher 수는 여전히 1입니다. inactive는 "연결 통로는 열어 두되 내보내지 않는 상태"입니다.

**생각해 볼 질문**: Nav2를 띄울 때 사람이 이 명령을 노드마다 치지는 않습니다. 그럼 누가 configure와 activate를 보낼까요? (힌트: `ros2 pkg executables nav2_lifecycle_manager`)

### 실습 9-4. 시뮬을 텔레옵으로 몰면서 지도 만들기 (bag 기록 포함)

**준비**: 터미널 5개. map_server 실습은 모두 Ctrl-C로 끕니다.

**직접 입력**:

터미널 1: 시뮬레이터

```bash
ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py
```

터미널 2: slam_toolbox (실시간, 비동기 방식)

```bash
ros2 launch slam_toolbox online_async_launch.py use_sim_time:=true
```

이 launch 파일의 `use_sim_time` 기본값은 이미 `true`이지만, 무엇에 기대고 있는지 드러나도록 직접 적습니다. 파라미터 파일은 기본값인 `/opt/ros/jazzy/share/slam_toolbox/config/mapper_params_online_async.yaml`이 쓰입니다. 그 안의 `odom_frame: odom`, `map_frame: map`, `base_frame: base_footprint`, `scan_topic: /scan`이 TurtleBot3 시뮬의 이름과 그대로 맞기 때문에 따로 고칠 것이 없습니다.

터미널 3: rviz2 (slam_toolbox가 제공하는 설정 파일 사용)

```bash
rviz2 -d /opt/ros/jazzy/share/slam_toolbox/config/slam_toolbox_default.rviz --ros-args -p use_sim_time:=true
```

터미널 4: bag 기록 (원서처럼 나중에 지도를 다시 만들 재료)

```bash
mkdir -p ~/rosbook_ws/bags && cd ~/rosbook_ws/bags
ros2 bag record -o tb3_drive --use-sim-time /scan /tf /tf_static /odom
```

터미널 5: 텔레옵

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args -p stamped:=true -p use_sim_time:=true
```

터미널 5에 포커스를 두고 천천히 몰면서 기둥 사이와 벽을 따라 한 바퀴 이상 돕니다. 같은 곳을 두 번 지나가면 slam_toolbox가 루프 폐쇄(loop closure)로 지도를 바로잡을 기회가 생깁니다. 회전은 특히 천천히 합니다 (`c` 키로 회전 속도를 줄일 수 있습니다).

지도가 충분히 채워지면 **터미널 4의 bag 기록만** Ctrl-C로 멈추고, 나머지는 켜 둔 채로 구조를 관찰합니다.

```bash
ros2 lifecycle get /slam_toolbox
ros2 node info /slam_toolbox
ros2 topic info -v /map
ros2 topic info -v /tf
ros2 run tf2_tools view_frames --ros-args -p use_sim_time:=true
ros2 run tf2_ros tf2_echo map base_footprint --ros-args -p use_sim_time:=true
```

**관찰**:

- `ros2 lifecycle get /slam_toolbox`가 `active [3]`입니다. 아무도 lifecycle 명령을 치지 않았는데 active인 이유는 launch 파일이 configure와 activate 이벤트를 보내기 때문입니다 (`online_async_launch.py`의 `EmitEvent`, `OnStateTransition` 부분).
- `ros2 node info /slam_toolbox`의 Subscribers에 `/scan: sensor_msgs/msg/LaserScan`, Publishers에 `/map: nav_msgs/msg/OccupancyGrid`, `/map_metadata`, `/pose`, `/tf`가 있습니다. Service Servers에는 lifecycle 서비스(`/slam_toolbox/change_state` 등)와 함께 `/slam_toolbox/save_map`, `/slam_toolbox/serialize_map`, `/slam_toolbox/dynamic_map`이 보입니다.
- `ros2 topic info -v /map`의 publisher QoS가 `TRANSIENT_LOCAL`입니다. 9-3의 map_server와 같습니다. 그래서 rviz2나 map_info를 나중에 켜도 지도를 받습니다.
- `ros2 topic info -v /tf`의 publisher 목록에 slam_toolbox, ros_gz_bridge 노드, robot_state_publisher가 함께 있습니다. 같은 토픽에 여러 노드가 각자 다른 변환을 냅니다.
- `view_frames`는 현재 폴더에 `frames_<날짜>.pdf`와 `.gv` 파일을 만듭니다. PDF를 열면 `map → odom → base_footprint → base_link → base_scan ...` 트리가 보이고, 각 화살표에 그 변환을 낸 노드 이름(Broadcaster)이 적혀 있습니다. 이 장의 구조 그림과 비교합니다.
  - `map → odom`: slam_toolbox
  - `odom → base_footprint`: Gazebo DiffDrive 플러그인이 gz 쪽 `/tf`로 내고, ros_gz_bridge가 ROS 2 `/tf`로 옮깁니다 (`turtlebot3_gazebo/params/turtlebot3_waffle_pi_bridge.yaml`의 `tf` 항목)
  - `base_footprint → base_link` 이하: robot_state_publisher (URDF의 고정 관절은 `/tf_static`, 바퀴 관절은 `/joint_states`를 받아 `/tf`)
- `tf2_echo map base_footprint`는 slam_toolbox의 보정과 오도메트리를 합친 로봇 위치를 보여 줍니다.

**지도 저장**: 지도가 마음에 들면 터미널 4(bag을 멈춘 터미널)에서 저장합니다.

```bash
ros2 run nav2_map_server map_saver_cli -f ~/rosbook_ws/maps/tb3_world
cat ~/rosbook_ws/maps/tb3_world.yaml
```

`tb3_world.pgm`과 `tb3_world.yaml` 두 파일이 생깁니다. YAML의 `origin`은 처음 보는 값일 것입니다. slam_toolbox 지도의 `map` 원점은 SLAM을 시작한 순간의 로봇 위치(= `odom` 원점)이고, `origin`은 그 기준에서 이미지 왼쪽 아래 모서리가 어디인지를 적은 것입니다. 이 사실은 10장에서 목표 좌표를 정할 때 다시 씁니다.

**bag 확인**:

```bash
ros2 bag info ~/rosbook_ws/bags/tb3_drive
ls ~/rosbook_ws/bags/tb3_drive
```

`Storage id: mcap`, 토픽별 메시지 수, `Duration`이 보입니다. `/tf_static`은 메시지가 1~2개뿐입니다. 고정 변환은 시작할 때 한 번만 발행되고, recorder가 늦게 붙어도 `transient_local` 덕분에 받아서 기록합니다.

다 확인했으면 터미널 1, 2, 3, 5를 모두 Ctrl-C로 끕니다.

**생각해 볼 질문**: bag을 기록할 때 `--use-sim-time`을 붙인 이유는 무엇일까요? (bag에는 메시지마다 "받은 시각"이 저장되고, `--clock`은 그 시각을 `/clock`으로 다시 냅니다.)

### 실습 9-5. bag 재생으로 지도 다시 만들기

**준비**: 터미널 4개. **Gazebo는 반드시 꺼 둡니다.** Gazebo가 켜져 있으면 Gazebo의 `/clock`과 bag의 `/clock`이 둘 다 나와서 시간이 앞뒤로 튀고, 실시간 `/scan`과 재생된 `/scan`이 섞입니다 (원서 PDF p.159의 경고와 같은 문제입니다).

**직접 입력**:

터미널 1: 이번에는 동기 방식 slam_toolbox를 씁니다. 동기 방식은 들어온 스캔을 건너뛰지 않고 모두 처리하므로 bag 재생에 맞습니다.

```bash
ros2 launch slam_toolbox online_sync_launch.py use_sim_time:=true
```

터미널 2: rviz2 (9-4와 같은 명령)

```bash
rviz2 -d /opt/ros/jazzy/share/slam_toolbox/config/slam_toolbox_default.rviz --ros-args -p use_sim_time:=true
```

터미널 3: 재생. bag 경로를 `--clock`보다 **앞에** 씁니다.

```bash
ros2 bag play ~/rosbook_ws/bags/tb3_drive --clock
```

터미널 4: 재생 중에 관찰합니다.

```bash
ros2 topic info -v /clock
ros2 topic echo /clock --once
ros2 node list
```

재생이 끝나면(터미널 3이 스스로 종료) 저장합니다.

```bash
ros2 run nav2_map_server map_saver_cli -f ~/rosbook_ws/maps/tb3_world_bag
```

**관찰**:

- `/clock`의 publisher는 `rosbag2_player` 하나뿐입니다. Gazebo가 꺼져 있으므로 ros_gz_bridge가 없습니다.
- `ros2 node list`에 Gazebo, bridge, robot_state_publisher가 없는데도 slam_toolbox가 지도를 만듭니다. slam_toolbox는 "누가" 보냈는지 모르고 `/scan`, `/tf`, `/tf_static`이라는 이름과 타입만 보고 데이터를 받기 때문입니다. bag player가 원래 노드들 자리를 대신합니다.
- 재생 속도를 바꾸려면 `-r 0.5`처럼 `--rate`를 줍니다. 처리 속도가 따라오지 못할 때 느리게 재생하면 지도가 나아질 수 있습니다.
- 9-4의 `tb3_world.pgm`과 `tb3_world_bag.pgm`을 이미지 뷰어(`eog`가 있으면 `eog ~/rosbook_ws/maps/tb3_world_bag.pgm`, 없으면 Windows 탐색기에서 `\\wsl.localhost\Ubuntu\home\<사용자>\rosbook_ws\maps`)로 열어 비교합니다.

slam_toolbox의 파라미터(예: `minimum_travel_distance`, `minimum_travel_heading`, `resolution`)를 바꾼 YAML을 만들어 `slam_params_file:=<경로>`로 주고, 같은 bag을 다시 재생하면 로봇을 다시 몰지 않고도 결과를 비교할 수 있습니다. 원서가 bag을 먼저 기록하라고 권하는 이유입니다 (원서 PDF p.166~167).

**생각해 볼 질문**: 이 실습에서 slam_toolbox를 `use_sim_time:=false`로 띄우면 노드의 "현재 시각"과 bag 안 메시지의 header 시각은 각각 무엇을 기준으로 할까요?

### 실습 9-6. 저장한 지도를 map_server로 다시 띄우기

**준비**: 터미널 3개. SLAM과 Gazebo는 꺼 둡니다.

**직접 입력**: 이번에는 lifecycle 전환을 사람이 하지 않고, Nav2의 lifecycle_manager에게 맡깁니다.

터미널 1:

```bash
ros2 run nav2_map_server map_server --ros-args -p yaml_filename:=$HOME/rosbook_ws/maps/tb3_world.yaml
```

터미널 2:

```bash
ros2 run nav2_lifecycle_manager lifecycle_manager --ros-args -p node_names:="['map_server']" -p autostart:=true
```

터미널 3:

```bash
ros2 lifecycle get /map_server
ros2 run nav_bot map_info
rviz2 --ros-args -p use_sim_time:=false
```

rviz2에서 Fixed Frame을 `map`으로 바꾸고, Add → By topic → `/map`의 Map 디스플레이를 추가합니다.

**관찰**:

- `ros2 lifecycle get /map_server`가 곧바로 `active [3]`입니다. 터미널 2의 로그에 `Configuring map_server`, `Activating map_server` 같은 줄이 보입니다. 9-3에서 손으로 보낸 전환을 lifecycle_manager가 서비스 호출로 대신 보낸 것입니다. 10장의 Nav2 launch 파일도 같은 방식으로 `lifecycle_manager_localization`, `lifecycle_manager_navigation`을 띄웁니다.
- map_info가 9-4의 지도 크기, 해상도, 원점을 출력합니다. 값이 `tb3_world.yaml`과 같은지 비교합니다.
- 이 실습은 시뮬 시각이 필요 없으므로 rviz2를 `use_sim_time:=false`로 띄웁니다. `/map`은 한 번 발행되고 끝나는 메시지라 시계와 상관없이 보입니다.
- (선택) 이미지 편집기로 `tb3_world.pgm`의 통로 하나에 검은 선을 긋고 저장한 뒤, map_server를 다시 실행합니다. rviz2에 그 선이 벽으로 보입니다. 10장의 경로 계획은 이 선을 넘지 않습니다 (원서 PDF p.157~158에 같은 활용이 나옵니다).

**생각해 볼 질문**: map_server만 띄웠을 때 `ros2 run tf2_ros tf2_echo map odom`은 무엇을 보여 줄까요?

## 4. 일부러 망가뜨려 보기

| 바꿀 것 | 예상 증상 | 원인을 확인하는 명령 |
|---|---|---|
| 9-3에서 configure만 하고 activate를 하지 않음 | map_info가 "/map 을 기다립니다"에서 멈춤. publisher는 있음 | `ros2 lifecycle get /map_server` → `inactive [2]`, `ros2 topic info -v /map` |
| `map_info.py`의 `DurabilityPolicy.TRANSIENT_LOCAL`을 `VOLATILE`로 바꾸고 다시 빌드한 뒤, activate **이후에** 실행 | 지도를 영영 받지 못함 (activate 전에 미리 켜 두었다면 받음) | `ros2 topic info -v /map`에서 subscriber의 Durability가 `VOLATILE`인지 확인. 같은 실험을 명령으로: `ros2 topic echo /map --once --no-arr --qos-durability volatile --qos-reliability reliable` |
| `tiny.yaml`의 `free_thresh`를 `0.25`로 바꾸고 map_server 재시작 | map_info가 `unknown=0`, `free=32`를 출력. 회색 칸이 빈 공간이 됨 | 1절의 식에 205를 넣어 보기 (p ≈ 0.196 < 0.25) |
| `tiny.yaml`의 `negate`를 `1`로 바꿈 | 벽과 빈 공간이 뒤바뀜 (`occupied`와 `free` 개수가 바뀜) | map_info 출력, rviz2 Map 디스플레이 |
| `yaml_filename` 경로를 틀리게 줌 (예: `tiny.yml`) | `configure`가 실패하고 상태가 `unconfigured`로 남음. 터미널 1에 파일 열기 실패 로그 | `ros2 lifecycle get /map_server`, 터미널 1 로그 |
| 9-4에서 텔레옵을 `stamped:=true` 없이 실행 | 키를 눌러도 로봇이 움직이지 않음 | `ros2 topic info -v /cmd_vel` → 타입이 둘(`Twist`, `TwistStamped`)로 나뉨 |
| 9-4에서 bag을 `/tf_static` 없이 기록하고 9-5를 진행 | slam_toolbox가 `base_scan` 프레임으로 가는 변환을 찾지 못해 스캔을 버리고 지도가 생기지 않음 | `ros2 bag info`, `ros2 run tf2_tools view_frames` (트리가 `base_footprint`에서 끊김) |
| 9-5에서 Gazebo를 끄지 않고 `--clock` 재생 | 시간이 앞뒤로 튀고 tf 경고가 쏟아지며 지도가 엉망이 됨 | `ros2 topic info -v /clock` → publisher가 2개 |
| 9-5에서 `ros2 bag play --clock ~/rosbook_ws/bags/tb3_drive` 순서로 입력 | `argument --clock: invalid positive_float value` 오류로 바로 종료 | `ros2 bag play -h`에서 `--clock [Hz]` 확인 |
| 9-4에서 slam_toolbox 실행 중 터미널 2를 Ctrl-C | rviz2의 지도가 더 이상 갱신되지 않고, `map` 프레임이 tf 트리에서 사라짐 (rviz2 Fixed Frame `map` 오류) | `ros2 run tf2_ros tf2_echo map odom --ros-args -p use_sim_time:=true` |

## 5. 확인 질문

<details><summary>Q1. 회색 205는 실습 9-1의 YAML에서 어떤 값이 되나요? (9-1 질문)</summary>

p = (255 - 205) / 255 ≈ 0.196 입니다. 정확히는 0.19608이라 `free_thresh: 0.196`보다 아주 조금 커서 "비어 있음"이 아니고, `occupied_thresh: 0.65`보다는 작아서 "막힘"도 아닙니다. 그래서 -1(모름)이 됩니다. map_saver_cli가 모르는 칸을 205로 저장하고 YAML에 `free_thresh: 0.196`을 쓰는 것도 이 경계를 맞추기 위해서입니다. 4절의 실험처럼 기준을 0.25로 올리면 같은 픽셀이 빈 공간으로 바뀝니다.

</details>

<details><summary>Q2. map_info는 왜 map_server 이름을 몰라도 지도를 받나요? (9-2 질문)</summary>

ROS 2 노드는 토픽 이름(`/map`)과 메시지 타입(`nav_msgs/msg/OccupancyGrid`)이 같고 QoS가 호환되면 DDS 디스커버리로 서로를 찾아 연결합니다. publisher가 누구인지는 연결 조건이 아닙니다. 그래서 9-4에서 slam_toolbox가 낸 지도도, 9-6에서 map_server가 낸 지도도 같은 노드로 받을 수 있습니다.

</details>

<details><summary>Q3. Nav2에서는 누가 configure와 activate를 보내나요? (9-3 질문)</summary>

`nav2_lifecycle_manager`의 `lifecycle_manager` 노드입니다. `node_names` 파라미터에 적힌 노드들에 순서대로 `change_state` 서비스를 호출하고, `autostart:=true`면 activate까지 진행합니다. 실습 9-6에서 직접 확인했고, 10장의 Nav2 launch 파일은 이 노드를 `lifecycle_manager_localization`(map_server, amcl 담당)과 `lifecycle_manager_navigation`(경로 계획과 제어 노드 담당) 두 개로 띄웁니다.

</details>

<details><summary>Q4. bag을 기록할 때 `--use-sim-time`을 붙인 이유는? (9-4 질문)</summary>

bag은 메시지마다 recorder가 받은 시각을 저장하고, `ros2 bag play ... --clock`은 그 시각을 `/clock`으로 냅니다. 옵션 없이 기록하면 받은 시각이 컴퓨터 시계(예: 1793110140초)로 저장되는데, 시뮬의 `/scan`과 `/tf` header에는 Gazebo 시각(예: 120초)이 들어 있습니다. 그러면 재생할 때 `/clock`과 메시지 header가 서로 다른 시계를 따르게 됩니다. `--use-sim-time`을 붙이면 recorder가 `/clock`을 기준으로 시각을 저장하므로 둘이 같은 시계가 됩니다. (컴퓨터 시계로 기록한 bag을 재생했을 때 `/clock`이 컴퓨터 시각으로 나오는 것은 확인했습니다. 시뮬 bag에서 이 차이가 slam_toolbox에 어떤 증상을 내는지는 7절에 적은 대로 확인하지 못했습니다.)

</details>

<details><summary>Q5. 9-5에서 slam_toolbox를 `use_sim_time:=false`로 띄우면? (9-5 질문)</summary>

노드의 현재 시각(`get_clock().now()`)은 컴퓨터 시계를 따르고, 재생된 메시지의 header는 기록 당시의 시뮬 시각을 담고 있습니다. 두 값이 수십 년 단위로 차이 나므로, 현재 시각 기준으로 tf를 찾거나 메시지가 너무 오래되었는지 판단하는 코드가 엉뚱하게 동작할 수 있습니다. 시뮬과 bag 재생에서는 시각을 다루는 모든 노드를 `use_sim_time:=true`로 맞추는 것이 원칙입니다.

</details>

<details><summary>Q6. map_server만 띄웠을 때 `tf2_echo map odom`은? (9-6 질문)</summary>

변환을 찾지 못한다는 메시지만 반복됩니다. map_server는 `/map` 토픽만 내고 tf는 내지 않습니다. 지도 위에서 로봇이 어디 있는지(`map → odom`)를 정하는 것은 SLAM 노드나 10장의 AMCL 같은 위치 추정 노드의 일입니다. "지도를 주는 노드"와 "지도 위 위치를 정하는 노드"가 분리되어 있다는 점이 10장의 출발점입니다.

</details>

## 6. 원서 대조 메모

- 원서 PDF p.157(인쇄 137): 예제 YAML은 `image: map.pgm`인데 바로 아래 본문은 지도가 `map.png`에 저장된다고 설명합니다. 예제 기준으로 PGM이 맞습니다.
- 원서 PDF p.159(인쇄 139): 경고 상자 안에 `--clock--`라는 오타가 있습니다. 옵션 이름은 `--clock`입니다. 그리고 ROS 2 Jazzy에서는 원서 순서(`play --clock 파일`)대로 쓰면 오류가 나므로 경로를 먼저 씁니다.
- 원서 PDF p.161(인쇄 141): GMapping 저자 이름이 한 곳에서 `Grisstti`로 잘못 적혀 있습니다 (바로 아래 참고문헌은 `Grisetti`).
- 원서 PDF p.163(인쇄 143)의 `rosparam set use_sim_time true`는 ROS 1의 전역 파라미터입니다. ROS 2에는 해당 명령이 없고, 노드마다 `use_sim_time`을 줍니다.
- 원서 PDF p.166(인쇄 146)의 gmapping 파라미터(`angularUpdate`, `linearUpdate`, `lskip`, `xmin` 등)는 slam_toolbox에 없습니다. 역할이 비슷한 것은 `minimum_travel_heading`, `minimum_travel_distance`, `throttle_scans`이고, slam_toolbox는 지도 크기를 미리 정하지 않고 필요한 만큼 늘립니다. 그래서 원서 PDF p.164의 "200 m × 200 m 기본 지도" 문제도 생기지 않습니다.
- 원서 PDF p.167~168(인쇄 147~148): ROS 1 map_server는 `/map_metadata` 토픽도 냈습니다. Jazzy의 Nav2 map_server는 `/map` 토픽과 `/map_server/map`(GetMap), `/map_server/load_map` 서비스만 있고 `/map_metadata`는 없습니다 (`ros2 topic list -t`로 확인). 메타데이터는 `/map` 메시지의 `info` 필드로 봅니다. 반면 slam_toolbox는 `/map_metadata`(`nav_msgs/msg/MapMetaData`)를 냅니다.
- 원서의 Stage 시뮬레이터, `turtlebot_stage`, `turtlebot_teleop`, `roscd mapping/maps`의 willow 지도는 ROS 2 Jazzy에 대응물이 없어 TurtleBot3 Gazebo 시뮬과 직접 만든 지도로 바꿨습니다.
- 원서는 지도를 만든 뒤 map_server를 실행하면 곧바로 `/map`이 나온다고 설명합니다. ROS 2에서는 lifecycle 전환이 필요하므로, 이 차이를 실습 9-3의 중심으로 삼았습니다.

## 7. 이 문서의 검증 상태

- 확인함 (설치된 Jazzy에서 직접 실행 또는 파일 확인):
  - 패키지 설치와 버전: `apt-cache policy`로 ros-jazzy-slam-toolbox 2.8.5, ros-jazzy-nav2-map-server 1.3.13, ros-jazzy-turtlebot3-navigation2 2.3.6, ros-jazzy-turtlebot3-cartographer 2.3.6, ros-jazzy-teleop-twist-keyboard 2.4.1, ros-jazzy-rosbag2-storage-mcap 0.26.11.
  - `ros2 interface show`로 `nav_msgs/msg/OccupancyGrid`, `nav_msgs/msg/MapMetaData` 필드와 data 배열 순서 주석.
  - slam_toolbox launch 파일(`online_async_launch.py`, `online_sync_launch.py`)의 인자(`use_sim_time` 기본 true, `slam_params_file`, `autostart`)와 LifecycleNode 자동 전환, `mapper_params_online_async.yaml`의 frame과 scan_topic 값. turtlebot3_cartographer의 `cartographer.launch.py` 인자. bridge YAML의 `tf`, `cmd_vel`(TwistStamped) 항목, 모델 SDF의 DiffDrive `odom → base_footprint`, URDF의 `base_footprint → base_link` 고정 관절.
  - 실습 9-1, 9-2, 9-3을 별도 워크스페이스에서 그대로 실행: PGM/YAML 생성, `nav_bot` 생성(`ros2 pkg create` 인자 순서 포함), 빌드, `colcon test`(flake8, pep257, copyright 통과), map_server의 `unconfigured → inactive → active → inactive` 전환과 각 단계의 토픽·QoS·서비스, inactive에서 미수신, active 후 수신, 늦게 시작한 노드의 수신, `free=28 occupied=28 unknown=4`와 `(3.00, 0.50) ... = -1` 출력.
  - 4절 실험 중 VOLATILE 구독자의 미수신(`ros2 topic echo --qos-durability volatile`이 타임아웃), `free_thresh: 0.25`일 때 `unknown=0 free=32`.
  - `map_saver_cli -f`로 저장: YAML이 `mode: trinary`, `free_thresh: 0.196`, `occupied_thresh: 0.65`로 써지고 PGM 픽셀이 0/254(/205)인 것.
  - `ros2 bag record -o`, `ros2 bag info`(Storage id mcap, `/tf_static` 1개 기록), `ros2 bag play <경로> --clock`의 `/clock` 발행, `ros2 bag play --clock <경로>` 순서의 오류 메시지.
  - lifecycle_manager로 map_server 자동 활성화 (실습 9-6 앞부분): 로그의 `Configuring map_server`, `Activating map_server`, `Managed nodes are active`, 그리고 `active [3]`. 이때 토픽은 `/map`, `/bond`, `/diagnostics` 등이고 `/map_metadata`는 없음.
  - slam_toolbox를 Gazebo 없이 `online_async_launch.py use_sim_time:=false`로 단독 실행: launch만으로 `active [3]`, `ros2 node info /slam_toolbox`의 토픽과 서비스, `/map` publisher QoS(RELIABLE, KEEP_LAST 1, TRANSIENT_LOCAL).
  - 검증 환경: README의 설정대로 `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`로 실행했고, 다른 작업과 겹치지 않도록 `ROS_DOMAIN_ID=24`, `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST`, CLI `--no-daemon`을 썼습니다.
- 확인 못 함:
  - Gazebo, rviz2를 띄우는 실습 9-4, 9-5, 9-6의 rviz2 부분 전체 (GUI). 특히 slam_toolbox가 실제로 만든 지도 모양, `view_frames` PDF 내용, 실시간 `/tf` publisher 목록, bag 재생으로 만든 지도의 품질.
  - 9-4의 `ros2 bag record --use-sim-time` 동작과, 이 옵션 없이 기록한 시뮬 bag이 slam_toolbox에 주는 실제 증상.
  - 4절 표 중 `/tf_static` 누락, Gazebo와 bag `/clock` 동시 발행, `negate: 1`, 잘못된 `yaml_filename`, slam_toolbox 종료 실험의 실제 출력.
