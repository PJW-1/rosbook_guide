# 16장. 나만의 이동 로봇 1부

- 원서: Chapter 16. Your Own Mobile Robot, PDF p.295~318 (인쇄 쪽 = PDF 쪽 - 20)
- 선행 조건: 15장까지 진행한 상태. 7장과 8장에서 TurtleBot3 시뮬로 `/cmd_vel`을 보내 본 경험.
- 새로 설치할 것: `sudo apt install ros-jazzy-joint-state-publisher-gui` (16-4의 슬라이더 창용). `xacro`, `robot_state_publisher`, `ros_gz_sim`, `ros_gz_bridge`, `check_urdf`, `teleop_twist_keyboard`는 이미 설치되어 있습니다.

## 이 장에서 체감할 구조

이동 로봇의 바깥 약속은 "`/cmd_vel`을 받고 `/odom`과 `odom → base_footprint` 변환을 낸다" 하나입니다. 그 약속을 지키는 쪽이 파이썬 가짜 드라이버이든 Gazebo이든 다른 노드는 차이를 모릅니다.

```
/cmd_vel (Twist) --> [fake_base_driver] 또는 [ros_gz_bridge → Gazebo DiffDrive] --> /odom, /tf(odom→base_footprint)
robot_description (xacro→URDF) --> [robot_state_publisher] + /joint_states --> /tf, /tf_static (로봇 몸체 좌표들)
```

## 1. 목표와 개념

원서는 바퀴 두 개와 캐스터 하나로 된 작은 로봇(TortoiseBot)을 직접 설계해 시뮬레이터에 올립니다. 이 장의 개념은 세 가지입니다.

- 메시지 인터페이스: 이동 로봇은 속도 명령(`geometry_msgs/msg/Twist`)을 받고, 자기 위치 추정(`nav_msgs/msg/Odometry`)과 좌표 변환을 냅니다. 이 약속만 지키면 7~10장에서 쓴 도구(teleop, Nav2)가 그대로 붙습니다.
- 하드웨어 드라이버: 속도 명령을 바퀴 속도로 바꾸고, 바퀴 회전을 다시 위치로 적분하는 노드입니다. 실물이면 모터 드라이버를, 시뮬이면 Gazebo의 DiffDrive 시스템을 씁니다.
- 로봇 모델(URDF): 링크(몸체 조각)와 조인트(조각 사이의 연결)로 로봇의 모양, 충돌 형상, 질량을 적은 XML입니다. xacro는 URDF에 변수와 매크로를 더한 전처리기입니다. `robot_state_publisher`는 이 모델과 `/joint_states`로 각 링크의 좌표 변환을 냅니다.

비유: `/cmd_vel`과 `/odom`은 자동차의 페달과 계기판입니다. 운전자(Nav2, teleop)는 엔진이 가솔린인지 전기인지(실물 드라이버인지 Gazebo인지) 몰라도 운전할 수 있습니다.

이 가이드의 TortoiseBot 치수(몸체 0.30 × 0.20 × 0.10 m, 바퀴 반지름 0.04 m)는 원서와 다르게 새로 정했습니다. 17장의 Nav2 기본 설정과 TurtleBot3 연습장 지도에 맞는 크기입니다.

## 2. 원서(ROS 1)와 달라지는 점

| 원서 (ROS 1) | ROS 2 Jazzy | 이유와 주의점 |
|---|---|---|
| 순수 URDF 파일 | xacro 파일 (`.urdf.xacro`) | 치수를 변수로 두고, 바퀴처럼 반복되는 부분은 매크로로 만듭니다. |
| `urdf_tutorial`의 display 런치 | 직접 만든 `display.launch.py` | `urdf_tutorial`은 설치되어 있지 않고, 런치 파일 세 줄짜리 구조를 직접 보는 편이 배울 것이 많습니다. |
| `robot_description`이 파라미터 서버의 전역 값 | `robot_state_publisher` 노드의 파라미터이자 `/robot_description` 토픽 | ROS 2에는 전역 파라미터 서버가 없습니다. 다른 노드는 TRANSIENT_LOCAL 토픽으로 모델을 받습니다. |
| Gazebo Classic + `gazebo_ros` | Gazebo Harmonic(gz-sim 8) + `ros_gz_sim`, `ros_gz_bridge` | Gazebo 토픽과 ROS 토픽은 별개이고, 브리지 노드가 yaml에 적은 것만 타입을 바꿔 이어 줍니다. |
| `spawn_model` | `ros_gz_sim create` | `-topic robot_description`으로 모델을 읽어 월드에 넣습니다. |
| `libgazebo_ros_diff_drive.so` 플러그인 | `gz-sim-diff-drive-system` + 브리지 | 플러그인은 Gazebo 토픽만 압니다. ROS의 `/cmd_vel`과의 연결은 브리지가 합니다. |
| `/cmd_vel` 타입은 항상 `Twist` | 로봇마다 다름 | TurtleBot3 시뮬은 `TwistStamped`, 이 장의 로봇은 브리지 yaml에 `Twist`로 적었습니다. 타입은 브리지 설정이 정합니다. |

## 3. 실습

### 실습 16-1. 이동 로봇의 약속을 타입으로 보기

**준비**: 터미널 1개.

**직접 입력**:

```bash
ros2 interface show geometry_msgs/msg/Twist
ros2 interface show geometry_msgs/msg/TwistStamped
ros2 interface show nav_msgs/msg/Odometry
```

**관찰**:

- `Twist`는 `linear`(x, y, z)와 `angular`(x, y, z) 두 벡터뿐입니다. 바퀴 두 개 로봇은 `linear.x`(전진 속도)와 `angular.z`(회전 속도)만 씁니다.
- `TwistStamped`는 같은 `Twist` 앞에 `header`(시각과 좌표계 이름)가 붙은 타입입니다. 내용이 비슷해도 타입 이름이 다르면 서로 연결되지 않습니다.
- `Odometry`에는 `header.frame_id`(보통 `odom`), `child_frame_id`(로봇 기준 좌표계), 공분산이 붙은 위치와 속도가 들어 있습니다.

**생각해 볼 질문**: `Odometry`에 속도(`twist`)까지 들어 있는 이유는 무엇일까요?

### 실습 16-2. 패키지와 가짜 하드웨어 드라이버

원서 PDF p.297~300의 메시지 인터페이스와 하드웨어 드라이버 개념을, 바퀴 없이 계산만 하는 드라이버로 확인합니다. 바퀴 두 개 로봇은 "제자리에서 돌 수 있는 외발 자전거"(unicycle) 모델로 근사할 수 있습니다.

**준비**: 터미널 3개.

**직접 입력**:

```bash
cd ~/rosbook_ws/src
ros2 pkg create --build-type ament_python --license Apache-2.0 tortoisebot \
  --dependencies rclpy geometry_msgs nav_msgs tf2_ros
mkdir -p tortoisebot/launch tortoisebot/urdf tortoisebot/config tortoisebot/worlds
```

`~/rosbook_ws/src/tortoisebot/tortoisebot/fake_base_driver.py`

```python
import math

import rclpy
from geometry_msgs.msg import TransformStamped, Twist
from nav_msgs.msg import Odometry
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from tf2_ros import TransformBroadcaster


class FakeBaseDriver(Node):
    def __init__(self):
        super().__init__('fake_base_driver')
        self.x = 0.0
        self.y = 0.0
        self.yaw = 0.0
        self.cmd = Twist()
        self.last_cmd_time = self.get_clock().now()
        self.last_time = self.get_clock().now()

        self.cmd_sub = self.create_subscription(
            Twist, 'cmd_vel', self.on_cmd_vel, 10)
        self.odom_pub = self.create_publisher(Odometry, 'odom', 10)
        self.tf_broadcaster = TransformBroadcaster(self)
        self.timer = self.create_timer(0.02, self.on_timer)

    def on_cmd_vel(self, msg):
        self.cmd = msg
        self.last_cmd_time = self.get_clock().now()

    def on_timer(self):
        now = self.get_clock().now()
        dt = (now - self.last_time).nanoseconds * 1e-9
        self.last_time = now
        if (now - self.last_cmd_time).nanoseconds > 0.5e9:
            self.cmd = Twist()

        v = self.cmd.linear.x
        w = self.cmd.angular.z
        self.x += v * math.cos(self.yaw) * dt
        self.y += v * math.sin(self.yaw) * dt
        self.yaw += w * dt
        qz = math.sin(self.yaw / 2.0)
        qw = math.cos(self.yaw / 2.0)

        odom = Odometry()
        odom.header.stamp = now.to_msg()
        odom.header.frame_id = 'odom'
        odom.child_frame_id = 'base_footprint'
        odom.pose.pose.position.x = self.x
        odom.pose.pose.position.y = self.y
        odom.pose.pose.orientation.z = qz
        odom.pose.pose.orientation.w = qw
        odom.twist.twist.linear.x = v
        odom.twist.twist.angular.z = w
        self.odom_pub.publish(odom)

        t = TransformStamped()
        t.header = odom.header
        t.child_frame_id = 'base_footprint'
        t.transform.translation.x = self.x
        t.transform.translation.y = self.y
        t.transform.rotation.z = qz
        t.transform.rotation.w = qw
        self.tf_broadcaster.sendTransform(t)


def main(args=None):
    rclpy.init(args=args)
    node = FakeBaseDriver()
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

`~/rosbook_ws/src/tortoisebot/setup.py`는 맨 위에 `from glob import glob`를 추가하고, `data_files`와 `entry_points`를 아래처럼 고칩니다. 이 장과 17장에서 만들 런치, 모델, 설정, 월드 파일이 설치 폴더(`share/tortoisebot/`)로 복사되게 하는 설정입니다.

```python
from glob import glob

from setuptools import find_packages, setup

package_name = 'tortoisebot'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        ('share/' + package_name + '/launch', glob('launch/*.launch.py')),
        ('share/' + package_name + '/urdf', glob('urdf/*.xacro')),
        ('share/' + package_name + '/config', glob('config/*.yaml')),
        ('share/' + package_name + '/worlds', glob('worlds/*.sdf')),
    ],
```

```python
    entry_points={
        'console_scripts': [
            'fake_base_driver = tortoisebot.fake_base_driver:main',
        ],
    },
```

`package.xml`의 `<depend>` 줄 아래에 실행할 때 필요한 패키지를 적습니다. 빌드에는 영향이 없지만, 이 패키지가 무엇에 기대는지 한눈에 보이게 합니다.

```xml
  <exec_depend>xacro</exec_depend>
  <exec_depend>robot_state_publisher</exec_depend>
  <exec_depend>joint_state_publisher_gui</exec_depend>
  <exec_depend>rviz2</exec_depend>
  <exec_depend>ros_gz_sim</exec_depend>
  <exec_depend>ros_gz_bridge</exec_depend>
  <exec_depend>nav2_minimal_tb3_sim</exec_depend>
  <exec_depend>nav2_bringup</exec_depend>
```

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select tortoisebot
source ~/rosbook_ws/install/setup.bash
ros2 run tortoisebot fake_base_driver
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `self.x`, `self.y`, `self.yaw` | 출발점(odom 원점) 기준 로봇의 위치와 방향입니다. 실물 드라이버라면 바퀴 엔코더로 계산합니다. |
| `create_subscription(Twist, 'cmd_vel', ...)` | 입력 약속입니다. 타입은 `Twist`로 정했습니다. |
| `if (now - self.last_cmd_time)... > 0.5e9` | 0.5초 동안 명령이 없으면 멈춥니다. 명령을 보내던 노드가 죽었을 때 로봇이 계속 달리지 않게 하는 안전장치입니다. |
| `self.x += v * math.cos(self.yaw) * dt` 등 | unicycle 모델의 적분입니다. 전진 속도를 현재 방향으로 나누어 x, y에 더하고, 회전 속도를 방향에 더합니다. |
| `qz`, `qw` | z축 회전만 있는 쿼터니언입니다. 각도의 절반에 대한 sin, cos입니다. |
| `odom.header.frame_id = 'odom'`, `child_frame_id = 'base_footprint'` | "odom 좌표계에서 본 base_footprint의 위치"라는 뜻입니다. REP-105의 좌표계 이름을 따릅니다. |
| `TransformBroadcaster`, `sendTransform` | 같은 내용을 `/tf` 토픽으로도 냅니다. rviz2와 Nav2는 `/odom` 토픽보다 이 변환을 주로 씁니다. |
| `data_files`의 `glob(...)` | 폴더 안 파일을 설치 폴더로 복사합니다. 파일을 새로 추가하면 다시 빌드해야 복사됩니다. |

**관찰**: 두 번째 터미널에서 0.2 m/s 전진과 0.5 rad/s 회전을 10 Hz로 보냅니다.

```bash
ros2 topic pub -r 10 /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.2}, angular: {z: 0.5}}"
```

세 번째 터미널에서 확인합니다.

```bash
ros2 topic info -v /cmd_vel
ros2 topic echo --once /odom --field pose.pose
ros2 run tf2_ros tf2_echo odom base_footprint
```

- `/cmd_vel`의 Subscription에 `fake_base_driver`가 `geometry_msgs/msg/Twist` 타입으로 보입니다.
- `/odom`의 위치가 원을 그리며 바뀝니다. 몇 초 뒤 x, y가 0.3 안팎이고 orientation의 z, w가 0이 아닙니다.
- `tf2_echo`는 처음 한 번 `frame does not exist`를 낼 수 있고, 곧 Translation과 RPY의 yaw 값을 1초마다 출력합니다.
- pub을 Ctrl+C로 멈추면 0.5초 뒤 위치가 더 이상 바뀌지 않습니다.

**생각해 볼 질문**: Nav2 같은 노드가 이 가짜 드라이버와 Gazebo 로봇을 구분할 수 있을까요? 구분할 수 있다면 어디서 차이가 드러날까요?

### 실습 16-3. 몸체만 있는 첫 모델

원서 PDF p.301부터의 URDF 만들기를 xacro로 합니다. 먼저 상자 하나와, 그 바로 아래 바닥에 붙은 기준 좌표계만 만듭니다.

**준비**: 16-2의 노드는 모두 멈춥니다.

**직접 입력**: `~/rosbook_ws/src/tortoisebot/urdf/tortoisebot.urdf.xacro`

```xml
<?xml version="1.0"?>
<robot name="tortoisebot" xmlns:xacro="http://www.ros.org/wiki/xacro">

  <xacro:property name="chassis_l" value="0.30"/>
  <xacro:property name="chassis_w" value="0.20"/>
  <xacro:property name="chassis_h" value="0.10"/>
  <xacro:property name="chassis_z" value="0.09"/>

  <material name="shell">
    <color rgba="0.35 0.55 0.30 1"/>
  </material>

  <link name="base_footprint"/>

  <link name="base_link">
    <visual>
      <geometry>
        <box size="${chassis_l} ${chassis_w} ${chassis_h}"/>
      </geometry>
      <material name="shell"/>
    </visual>
  </link>

  <joint name="base_joint" type="fixed">
    <parent link="base_footprint"/>
    <child link="base_link"/>
    <origin xyz="0 0 ${chassis_z}" rpy="0 0 0"/>
  </joint>

</robot>
```

```bash
cd ~/rosbook_ws/src/tortoisebot/urdf
xacro tortoisebot.urdf.xacro > /tmp/tortoisebot.urdf
check_urdf /tmp/tortoisebot.urdf
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `xmlns:xacro=...` | 이 파일에서 `xacro:` 태그를 쓰겠다는 선언입니다. |
| `xacro:property` | 치수 변수입니다. `${chassis_l}`처럼 꺼내 쓰고, 계산식도 쓸 수 있습니다. |
| `chassis_z` 0.09 | 몸체 중심의 높이입니다. 바퀴 지름(0.08)보다 조금 높게 두어 몸체 바닥이 0.04 m 높이에 뜨게 합니다. |
| `material` | rviz2에서 보일 색입니다. Gazebo는 이 색을 쓰지 않습니다. |
| `<link name="base_footprint"/>` | 모양 없는 링크입니다. 로봇 중심 바로 아래 바닥 점을 뜻하고, 2D 내비게이션의 기준점이 됩니다. |
| `<link name="base_link">` | 몸체입니다. 지금은 보이는 모양(`visual`)만 있습니다. |
| `joint type="fixed"` | 두 링크를 움직이지 않게 붙입니다. `origin`은 부모(base_footprint) 기준 자식(base_link)의 위치입니다. |

**관찰**: `check_urdf` 출력에 `root Link: base_footprint has 1 child(ren)`과 `child(1): base_link`가 보입니다. 다음 실습의 `display.launch.py`를 만든 뒤 rviz2에서 초록 상자를 볼 수 있습니다.

**생각해 볼 질문**: `base_footprint`처럼 모양 없는 링크를 따로 두는 이유는 무엇일까요?

### 실습 16-4. 바퀴와 캐스터, 그리고 모델 보기

원서 PDF p.303~308처럼 바퀴, 충돌 형상, 질량을 더합니다. Gazebo는 `collision`과 `inertial`이 없는 링크를 물리적으로 다룰 수 없으므로 모든 링크에 넣습니다.

**준비**: 터미널 2개. `sudo apt install ros-jazzy-joint-state-publisher-gui`를 마친 상태.

**직접 입력**: `~/rosbook_ws/src/tortoisebot/urdf/tortoisebot.urdf.xacro`를 아래 내용으로 바꿉니다.

```xml
<?xml version="1.0"?>
<robot name="tortoisebot" xmlns:xacro="http://www.ros.org/wiki/xacro">

  <xacro:property name="chassis_l" value="0.30"/>
  <xacro:property name="chassis_w" value="0.20"/>
  <xacro:property name="chassis_h" value="0.10"/>
  <xacro:property name="chassis_z" value="0.09"/>
  <xacro:property name="wheel_r" value="0.04"/>
  <xacro:property name="wheel_w" value="0.03"/>
  <xacro:property name="wheel_x" value="-0.09"/>
  <xacro:property name="wheel_y" value="0.125"/>
  <xacro:property name="front_r" value="0.025"/>

  <material name="shell">
    <color rgba="0.35 0.55 0.30 1"/>
  </material>
  <material name="black">
    <color rgba="0.1 0.1 0.1 1"/>
  </material>

  <xacro:macro name="box_inertial" params="m x y z">
    <inertial>
      <mass value="${m}"/>
      <inertia ixx="${m*(y*y+z*z)/12}" ixy="0" ixz="0"
               iyy="${m*(x*x+z*z)/12}" iyz="0"
               izz="${m*(x*x+y*y)/12}"/>
    </inertial>
  </xacro:macro>

  <xacro:macro name="cylinder_inertial" params="m r h">
    <inertial>
      <mass value="${m}"/>
      <inertia ixx="${m*(3*r*r+h*h)/12}" ixy="0" ixz="0"
               iyy="${m*(3*r*r+h*h)/12}" iyz="0"
               izz="${m*r*r/2}"/>
    </inertial>
  </xacro:macro>

  <xacro:macro name="wheel" params="name r w m">
    <link name="${name}">
      <visual>
        <geometry><cylinder radius="${r}" length="${w}"/></geometry>
        <material name="black"/>
      </visual>
      <collision>
        <geometry><cylinder radius="${r}" length="${w}"/></geometry>
      </collision>
      <xacro:cylinder_inertial m="${m}" r="${r}" h="${w}"/>
    </link>
  </xacro:macro>

  <link name="base_footprint"/>

  <link name="base_link">
    <visual>
      <geometry>
        <box size="${chassis_l} ${chassis_w} ${chassis_h}"/>
      </geometry>
      <material name="shell"/>
    </visual>
    <collision>
      <geometry>
        <box size="${chassis_l} ${chassis_w} ${chassis_h}"/>
      </geometry>
    </collision>
    <xacro:box_inertial m="1.0" x="${chassis_l}" y="${chassis_w}" z="${chassis_h}"/>
  </link>

  <joint name="base_joint" type="fixed">
    <parent link="base_footprint"/>
    <child link="base_link"/>
    <origin xyz="0 0 ${chassis_z}" rpy="0 0 0"/>
  </joint>

  <xacro:wheel name="left_wheel" r="${wheel_r}" w="${wheel_w}" m="0.2"/>
  <joint name="left_wheel_joint" type="continuous">
    <parent link="base_link"/>
    <child link="left_wheel"/>
    <origin xyz="${wheel_x} ${wheel_y} ${wheel_r - chassis_z}" rpy="${-pi/2} 0 0"/>
    <axis xyz="0 0 1"/>
  </joint>

  <xacro:wheel name="right_wheel" r="${wheel_r}" w="${wheel_w}" m="0.2"/>
  <joint name="right_wheel_joint" type="continuous">
    <parent link="base_link"/>
    <child link="right_wheel"/>
    <origin xyz="${wheel_x} ${-wheel_y} ${wheel_r - chassis_z}" rpy="${-pi/2} 0 0"/>
    <axis xyz="0 0 1"/>
  </joint>

  <link name="front_caster">
    <visual>
      <geometry><box size="0.03 0.03 0.04"/></geometry>
      <material name="shell"/>
    </visual>
    <collision>
      <geometry><box size="0.03 0.03 0.04"/></geometry>
    </collision>
    <xacro:box_inertial m="0.05" x="0.03" y="0.03" z="0.04"/>
  </link>
  <joint name="front_caster_joint" type="continuous">
    <parent link="base_link"/>
    <child link="front_caster"/>
    <origin xyz="0.17 0 -0.03" rpy="0 0 0"/>
    <axis xyz="0 0 1"/>
    <dynamics damping="0.005"/>
  </joint>

  <xacro:wheel name="front_wheel" r="${front_r}" w="0.02" m="0.05"/>
  <joint name="front_wheel_joint" type="continuous">
    <parent link="front_caster"/>
    <child link="front_wheel"/>
    <origin xyz="-0.02 0 -0.035" rpy="${-pi/2} 0 0"/>
    <axis xyz="0 0 1"/>
  </joint>

</robot>
```

`~/rosbook_ws/src/tortoisebot/launch/display.launch.py`

```python
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import Command, LaunchConfiguration
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def generate_launch_description():
    pkg_share = get_package_share_directory('tortoisebot')
    default_model = os.path.join(pkg_share, 'urdf', 'tortoisebot.urdf.xacro')

    model = LaunchConfiguration('model')
    robot_description = ParameterValue(
        Command(['xacro ', model]), value_type=str)

    return LaunchDescription([
        DeclareLaunchArgument('model', default_value=default_model),
        Node(
            package='robot_state_publisher',
            executable='robot_state_publisher',
            parameters=[{'robot_description': robot_description}],
        ),
        Node(
            package='joint_state_publisher_gui',
            executable='joint_state_publisher_gui',
        ),
        Node(
            package='rviz2',
            executable='rviz2',
        ),
    ])
```

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select tortoisebot
xacro ~/rosbook_ws/src/tortoisebot/urdf/tortoisebot.urdf.xacro > /tmp/tortoisebot.urdf
check_urdf /tmp/tortoisebot.urdf
ros2 launch tortoisebot display.launch.py
```

rviz2에서 Fixed Frame을 `base_footprint`로 바꾸고, Add로 `RobotModel`을 추가한 뒤 Description Topic을 `/robot_description`으로 고릅니다. `TF` 디스플레이도 추가합니다.

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `box_inertial`, `cylinder_inertial` | 상자와 원기둥의 관성 모멘트 공식을 매크로로 만들었습니다. 질량만 넣으면 관성 값이 계산됩니다. |
| `xacro:macro name="wheel"` | 모양, 충돌, 질량이 같은 바퀴를 한 줄로 만들기 위한 매크로입니다. |
| `type="continuous"` | 한계 없이 계속 도는 조인트입니다. 바퀴와 캐스터 회전축에 씁니다. |
| `rpy="${-pi/2} 0 0"` | URDF 원기둥은 z축 방향으로 서 있으므로, x축으로 -90도 눕혀 바퀴처럼 만듭니다. 눕힌 뒤의 z축이 로봇의 왼쪽(+y)을 향하므로 `axis 0 0 1`로 돌면 앞으로 굴러갑니다. |
| `${wheel_r - chassis_z}` | 바퀴 중심을 바닥에서 반지름만큼 높이에 둡니다. base_link 중심이 0.09에 있으므로 -0.05가 됩니다. |
| `front_caster_joint`의 `dynamics damping` | 캐스터가 시뮬에서 지나치게 흔들리지 않도록 작은 감쇠를 줍니다. |
| `front_wheel_joint` 원점 `-0.02 0 -0.035` | 캐스터 바퀴를 회전축보다 조금 뒤에 달아서, 캐스터가 진행 방향을 따라가게 합니다. 바퀴 아래 끝이 바닥 높이(0)에 닿도록 높이를 맞췄습니다. |
| `Command(['xacro ', model])` | 런치할 때 xacro를 실행해 URDF 문자열을 만듭니다. |
| `ParameterValue(..., value_type=str)` | 결과를 문자열 파라미터로 넘깁니다. 이것이 없으면 런치가 문자열을 yaml로 해석하려다 실패할 수 있습니다. |
| `joint_state_publisher_gui` | 움직이는 조인트마다 슬라이더를 띄우고 `/joint_states`를 냅니다. 실물이나 시뮬에서는 이 자리를 드라이버가 채웁니다. |

**관찰**: `check_urdf`는 `base_footprint` 아래에 `base_link`, 그 아래 `front_caster`(그 아래 `front_wheel`), `left_wheel`, `right_wheel`을 보여 줍니다. 런치 뒤 다른 터미널에서 구조를 확인합니다.

```bash
ros2 node list
ros2 topic info -v /robot_description
ros2 topic echo --once /joint_states --field name
```

- `/robot_description`의 publisher는 `robot_state_publisher`이고 Durability가 `TRANSIENT_LOCAL`입니다. 나중에 켠 노드도 마지막 모델을 받을 수 있게 하는 QoS입니다.
- `/joint_states`의 이름 목록에 움직이는 조인트 4개(`left_wheel_joint`, `right_wheel_joint`, `front_caster_joint`, `front_wheel_joint`)가 있습니다. 고정 조인트 `base_joint`는 없습니다.
- rviz2에서 슬라이더를 움직이면 바퀴와 캐스터가 돕니다.

**생각해 볼 질문**: `joint_state_publisher_gui`를 끄면 rviz2의 바퀴는 어떻게 보일까요? 몸체는요?

### 실습 16-5. URDF가 SDF로 바뀌는 모습 보기

Gazebo는 URDF가 아니라 SDF 형식을 씁니다. `ros_gz_sim create`에 URDF를 주면 내부에서 SDF로 바꿉니다. 그 결과를 미리 봅니다.

**준비**: 16-4에서 만든 `/tmp/tortoisebot.urdf`.

**직접 입력**:

```bash
gz sdf -k /tmp/tortoisebot.urdf
gz sdf -p /tmp/tortoisebot.urdf > /tmp/tortoisebot.sdf
grep -nE "<link name|<joint name" /tmp/tortoisebot.sdf
gz sdf --inertial-stats /tmp/tortoisebot.sdf
```

**관찰**:

- `gz sdf -k`는 `Valid.`를 출력합니다.
- SDF의 링크 목록에 `base_link`가 없습니다. 고정 조인트로 붙은 `base_link`는 `base_footprint`에 합쳐집니다(lumping). 조인트 목록에도 `base_joint`가 없고, `continuous` 조인트는 `revolute`로 바뀌어 있습니다.
- `--inertial-stats`의 전체 질량은 1.5 kg(몸체 1.0 + 바퀴 0.2 × 2 + 캐스터 0.05 + 캐스터 바퀴 0.05)입니다.

**생각해 볼 질문**: `base_link`가 SDF에서 사라지면, Gazebo 플러그인 설정에 `base_link`라는 이름을 적었을 때 어떤 일이 생길 수 있을까요?

### 실습 16-6. Gazebo에 올리기: DiffDrive, 브리지, spawn

원서 PDF p.309~316의 시뮬레이션을 Gazebo Harmonic으로 합니다. 연결은 세 단계입니다. Gazebo 안의 DiffDrive 시스템이 Gazebo 토픽 `cmd_vel`을 받고 `odom`, `tf`를 냅니다. 브리지가 그 Gazebo 토픽과 ROS 토픽을 잇습니다. `create`가 `/robot_description`을 읽어 월드에 로봇을 넣습니다.

**준비**: 16-4의 런치는 멈춥니다.

**직접 입력**: `~/rosbook_ws/src/tortoisebot/urdf/tortoisebot_gazebo.xacro`

```xml
<?xml version="1.0"?>
<robot xmlns:xacro="http://www.ros.org/wiki/xacro">

  <gazebo>
    <plugin filename="gz-sim-diff-drive-system"
            name="gz::sim::systems::DiffDrive">
      <left_joint>left_wheel_joint</left_joint>
      <right_joint>right_wheel_joint</right_joint>
      <wheel_separation>${2*wheel_y}</wheel_separation>
      <wheel_radius>${wheel_r}</wheel_radius>
      <topic>cmd_vel</topic>
      <odom_topic>odom</odom_topic>
      <tf_topic>tf</tf_topic>
      <frame_id>odom</frame_id>
      <child_frame_id>base_footprint</child_frame_id>
      <odom_publish_frequency>30</odom_publish_frequency>
    </plugin>

    <plugin filename="gz-sim-joint-state-publisher-system"
            name="gz::sim::systems::JointStatePublisher">
      <topic>joint_states</topic>
    </plugin>
  </gazebo>

</robot>
```

`tortoisebot.urdf.xacro`의 마지막 `</robot>` 바로 위에 한 줄을 추가합니다.

```xml
  <xacro:include filename="$(find tortoisebot)/urdf/tortoisebot_gazebo.xacro"/>
```

`~/rosbook_ws/src/tortoisebot/config/tortoisebot_bridge.yaml`

```yaml
- ros_topic_name: "clock"
  gz_topic_name: "clock"
  ros_type_name: "rosgraph_msgs/msg/Clock"
  gz_type_name: "gz.msgs.Clock"
  direction: GZ_TO_ROS

- ros_topic_name: "cmd_vel"
  gz_topic_name: "cmd_vel"
  ros_type_name: "geometry_msgs/msg/Twist"
  gz_type_name: "gz.msgs.Twist"
  direction: ROS_TO_GZ

- ros_topic_name: "odom"
  gz_topic_name: "odom"
  ros_type_name: "nav_msgs/msg/Odometry"
  gz_type_name: "gz.msgs.Odometry"
  direction: GZ_TO_ROS

- ros_topic_name: "tf"
  gz_topic_name: "tf"
  ros_type_name: "tf2_msgs/msg/TFMessage"
  gz_type_name: "gz.msgs.Pose_V"
  direction: GZ_TO_ROS

- ros_topic_name: "joint_states"
  gz_topic_name: "joint_states"
  ros_type_name: "sensor_msgs/msg/JointState"
  gz_type_name: "gz.msgs.Model"
  direction: GZ_TO_ROS
```

`~/rosbook_ws/src/tortoisebot/launch/sim.launch.py`

```python
import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import (AppendEnvironmentVariable, DeclareLaunchArgument,
                            IncludeLaunchDescription)
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import Command, LaunchConfiguration
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterValue


def generate_launch_description():
    pkg_share = get_package_share_directory('tortoisebot')
    gz_launch = os.path.join(
        get_package_share_directory('ros_gz_sim'), 'launch', 'gz_sim.launch.py')
    model = os.path.join(pkg_share, 'urdf', 'tortoisebot.urdf.xacro')
    bridge_config = os.path.join(pkg_share, 'config', 'tortoisebot_bridge.yaml')
    tb3_models = os.path.join(
        get_package_share_directory('nav2_minimal_tb3_sim'), 'models')

    robot_description = ParameterValue(
        Command(['xacro ', model]), value_type=str)

    return LaunchDescription([
        DeclareLaunchArgument('world', default_value='empty.sdf'),
        DeclareLaunchArgument('x', default_value='0.0'),
        DeclareLaunchArgument('y', default_value='0.0'),
        AppendEnvironmentVariable('GZ_SIM_RESOURCE_PATH', tb3_models),
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource(gz_launch),
            launch_arguments={
                'gz_args': ['-r ', LaunchConfiguration('world')],
                'on_exit_shutdown': 'true',
            }.items(),
        ),
        Node(
            package='robot_state_publisher',
            executable='robot_state_publisher',
            parameters=[{'robot_description': robot_description,
                         'use_sim_time': True}],
        ),
        Node(
            package='ros_gz_sim',
            executable='create',
            arguments=['-topic', 'robot_description', '-name', 'tortoisebot',
                       '-x', LaunchConfiguration('x'),
                       '-y', LaunchConfiguration('y'), '-z', '0.01'],
        ),
        Node(
            package='ros_gz_bridge',
            executable='parameter_bridge',
            parameters=[{'config_file': bridge_config,
                         'use_sim_time': True}],
        ),
    ])
```

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select tortoisebot
ros2 launch tortoisebot sim.launch.py
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `<gazebo>` (reference 없음) | 특정 링크가 아니라 모델 전체에 붙는 설정입니다. URDF를 SDF로 바꿀 때 그대로 SDF의 `<plugin>`이 됩니다. |
| `left_joint`, `right_joint` | DiffDrive가 속도를 줄 조인트 이름입니다. URDF의 조인트 이름과 정확히 같아야 합니다. |
| `wheel_separation`, `wheel_radius` | 바퀴 간격 0.25 m와 반지름 0.04 m입니다. xacro 변수를 그대로 써서 모델과 어긋나지 않게 합니다. |
| `topic`, `odom_topic`, `tf_topic` | Gazebo 쪽 토픽 이름입니다. ROS 토픽이 아닙니다. |
| `frame_id`, `child_frame_id` | 내보낼 odom 메시지와 변환의 좌표계 이름입니다. 16-2의 가짜 드라이버와 똑같이 맞췄습니다. |
| `JointStatePublisher` | 시뮬 속 조인트 각도를 Gazebo 토픽 `joint_states`로 냅니다. 16-4에서 슬라이더가 하던 일을 대신합니다. |
| `xacro:include` | 다른 xacro 파일을 이 자리에 끼워 넣습니다. `$(find tortoisebot)`은 설치된 패키지의 share 폴더입니다. 변수(`wheel_y`, `wheel_r`)가 정의된 뒤에 넣어야 합니다. |
| 브리지 yaml의 각 항목 | ROS 토픽 이름과 타입, Gazebo 토픽 이름과 타입, 방향을 한 줄씩 짝지읍니다. 적지 않은 토픽은 건너오지 않습니다. |
| `clock` 항목 | 시뮬 시각을 ROS의 `/clock`으로 보냅니다. `use_sim_time:=true`인 노드는 이 시각을 씁니다. |
| `cmd_vel`의 `ros_type_name` | 이 로봇의 `/cmd_vel` 타입을 정하는 곳이 바로 이 줄입니다. |
| `AppendEnvironmentVariable('GZ_SIM_RESOURCE_PATH', ...)` | Gazebo가 `model://` 주소로 모델을 찾을 폴더를 추가합니다. 17장의 연습장 월드가 이 폴더의 모델을 씁니다. |
| `gz_args: ['-r ', world]` | 월드 파일을 열고 바로 시뮬레이션을 시작(`-r`)합니다. |
| `on_exit_shutdown: 'true'` | Gazebo 창을 닫으면 런치 전체가 끝나게 합니다. 기본값은 `false`입니다. |
| `create`의 `-topic robot_description` | `robot_state_publisher`가 내는 `/robot_description`을 받아 로봇을 넣습니다. TRANSIENT_LOCAL이라 늦게 켜져도 받습니다. |
| `-z 0.01` | 바닥과 겹친 채 생성되지 않도록 조금 띄웁니다. |

**관찰**: Gazebo 창에 빈 바닥과 로봇이 나타납니다. 다른 터미널에서 확인합니다.

```bash
ros2 node list
ros2 topic list
ros2 topic info -v /cmd_vel
ros2 topic echo --once /clock
ros2 topic echo --once /joint_states --field name
gz topic -l
```

- ROS 토픽에 `/clock`, `/cmd_vel`, `/joint_states`, `/odom`, `/tf`가 있습니다.
- `/cmd_vel`의 Subscription 쪽 노드 이름은 `ros_gz_bridge`, 타입은 `geometry_msgs/msg/Twist`입니다.
- `gz topic -l`에는 Gazebo 쪽 토픽 `/cmd_vel`, `/odom`, `/tf`, `/joint_states`, `/world/<월드 이름>/...`이 따로 보입니다. 이름이 같아도 서로 다른 세계의 토픽입니다.

**생각해 볼 질문**: 브리지 yaml에서 `odom` 항목을 지우면, Gazebo 속 로봇은 여전히 움직일까요? ROS 쪽에서는 무엇이 사라질까요?

### 실습 16-7. 운전하기, 그리고 TurtleBot3와 비교하기

**준비**: 16-6의 `sim.launch.py`가 실행 중입니다.

**직접 입력**:

```bash
ros2 topic pub -r 10 /cmd_vel geometry_msgs/msg/Twist "{linear: {x: 0.2}}"
```

Ctrl+C로 발행을 멈춰도 로봇은 서지 않을 수 있습니다. Gazebo의 DiffDrive 플러그인은 마지막으로 받은 속도를 계속 쓰기 때문입니다. 정지 명령을 한 번 보낸 뒤 키보드로 운전합니다.

```bash
ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist "{}"
```

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard --ros-args -p use_sim_time:=true
ros2 topic echo /odom --field pose.pose.position
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `ros2 topic pub -r 10 ... Twist` | 0.2 m/s 전진 명령을 초당 10번 보냅니다. |
| `ros2 topic pub --once ... "{}"` | 모든 필드가 0인 `Twist`를 한 번 보냅니다. 이것이 정지 명령입니다. |
| `teleop_twist_keyboard` | 기본값(`stamped` 파라미터 `false`)으로 `Twist`를 냅니다. 이 로봇의 브리지 타입과 맞습니다. |

**관찰**:

- 0.2 m/s로 약 6초 보내면 `/odom`의 x가 1.2~1.3 정도 늘어납니다.
- TurtleBot3 시뮬(`turtlebot3_gazebo`)의 `/cmd_vel`은 `TwistStamped`입니다. 그 브리지 설정 파일을 직접 열어 보면 차이가 어디서 오는지 보입니다.

```bash
grep -A4 'cmd_vel' $(ros2 pkg prefix turtlebot3_gazebo)/share/turtlebot3_gazebo/params/turtlebot3_waffle_pi_bridge.yaml
grep -A4 'cmd_vel' ~/rosbook_ws/src/tortoisebot/config/tortoisebot_bridge.yaml
```

같은 Gazebo DiffDrive라도 브리지 yaml에 적은 `ros_type_name`이 `/cmd_vel`의 타입을 정합니다. 그래서 TurtleBot3 시뮬에 teleop을 쓸 때는 `-p stamped:=true`가 필요했고, 이 로봇에는 필요 없습니다.

**생각해 볼 질문**: 이 로봇의 `/cmd_vel`을 `TwistStamped`로 바꾸고 싶다면 어느 파일의 어느 줄을 고치면 될까요? 바꾼 뒤 teleop은 어떻게 실행해야 할까요?

## 4. 일부러 망가뜨려 보기

| 바꿀 것 | 예상 증상 | 원인을 확인하는 명령 |
|---|---|---|
| 브리지 yaml의 `cmd_vel` 항목 `ros_type_name`을 `geometry_msgs/msg/TwistStamped`로 바꾸고 다시 빌드, 실행 | `Twist`로 보내는 pub과 teleop이 `Waiting for at least 1 matching subscription(s)...`에 머물고 로봇이 움직이지 않습니다. | `ros2 topic info -v /cmd_vel`에서 bridge 쪽 타입을 봅니다. |
| `tortoisebot_gazebo.xacro`의 `child_frame_id`를 `base_footprnt`로 오타 | `/odom`은 나오지만 좌표 트리가 `odom → base_footprnt`와 `base_footprint → ...`로 갈라집니다. rviz2에서 Fixed Frame `odom`으로 로봇 모델이 보이지 않습니다. | `ros2 run tf2_tools view_frames`, `ros2 run tf2_ros tf2_echo odom base_footprint` |
| 브리지 yaml에서 `joint_states` 항목 삭제 | rviz2의 RobotModel에서 바퀴와 캐스터에 변환이 없다는 오류가 나고, 몸체만 제자리에 그려집니다. | `ros2 topic list`에서 `/joint_states`가 사라졌는지, `view_frames`에서 바퀴 링크가 없는지 봅니다. |
| rviz2를 `use_sim_time` 없이 실행 | 시뮬 시각(수십 초)과 벽시계 시각이 크게 달라 변환이 너무 오래되었다는 경고가 나고 모델 표시가 불안정합니다. | `ros2 param get /rviz2 use_sim_time`, `ros2 topic echo --once /clock` |
| `sim.launch.py` 실행 중에 `fake_base_driver`도 실행 | 두 노드가 같은 `/odom`과 `odom → base_footprint` 변환을 냅니다. 로봇 위치가 두 값 사이에서 튀어 보입니다. | `ros2 topic info /odom`에서 Publisher count가 2인지 봅니다. |
| `ros2 node list`에서 본 `robot_state_publisher`를 Ctrl+C로 종료 | `create`가 이미 끝났다면 Gazebo 속 로봇은 그대로지만, ROS 쪽에서 바퀴와 몸체 링크 변환이 사라집니다. | `ros2 topic info -v /tf_static`, `view_frames` |

## 5. 확인 질문

<details><summary>Q1. 16-1: Odometry에 속도까지 들어 있는 이유는?</summary>

위치만으로는 지금 얼마나 빨리 움직이는지 알 수 없고, 위치를 미분하면 잡음이 커집니다. 드라이버는 바퀴 속도를 직접 알고 있으므로 함께 보내 줍니다. Nav2의 컨트롤러와 velocity smoother가 이 값을 씁니다.

</details>

<details><summary>Q2. 16-2: 다른 노드가 가짜 드라이버와 Gazebo 로봇을 구분할 수 있을까요?</summary>

메시지 타입과 토픽 이름만 보면 구분할 수 없습니다. 차이는 발행 노드 이름(`topic info -v`), `/clock` 사용 여부, 그리고 장애물에 부딪히는지 같은 물리적 결과에서 드러납니다.

</details>

<details><summary>Q3. 16-3: 모양 없는 base_footprint를 두는 이유는?</summary>

바닥 위 로봇 중심점을 기준으로 삼으면 2D 내비게이션 계산이 높이와 무관해집니다. 몸체 높이가 바뀌어도 `base_joint`의 z값만 고치면 되고, 내비게이션 설정은 그대로 둘 수 있습니다.

</details>

<details><summary>Q4. 16-4: joint_state_publisher_gui를 끄면?</summary>

`robot_state_publisher`는 고정 조인트 변환을 `/tf_static`으로 한 번 내므로 몸체는 계속 보입니다. 움직이는 조인트는 `/joint_states`가 와야 변환을 낼 수 있으므로, 바퀴와 캐스터에는 변환이 없다는 오류가 표시됩니다.

</details>

<details><summary>Q5. 16-5: SDF에서 base_link가 사라지면?</summary>

Gazebo 안에는 `base_link`라는 링크가 없으므로, 링크 이름을 요구하는 플러그인이나 센서 설정에 `base_link`를 적으면 찾지 못할 수 있습니다. 이 장의 DiffDrive 설정은 조인트 이름과 좌표계 이름만 쓰고, 좌표계 이름은 메시지에 적히는 문자열일 뿐이라 영향을 받지 않습니다.

</details>

<details><summary>Q6. 16-6: 브리지에서 odom 항목을 지우면?</summary>

Gazebo 속 로봇은 그대로 움직입니다. DiffDrive는 Gazebo 토픽 `cmd_vel`만 받으면 되기 때문입니다. ROS 쪽에서는 `/odom` 토픽이 사라집니다. `/tf` 항목은 남아 있으므로 `odom → base_footprint` 변환은 계속 들어옵니다.

</details>

<details><summary>Q7. 16-7: /cmd_vel을 TwistStamped로 바꾸려면?</summary>

`config/tortoisebot_bridge.yaml`의 `cmd_vel` 항목에서 `ros_type_name`을 `geometry_msgs/msg/TwistStamped`로 바꾸고 다시 빌드합니다. teleop은 `--ros-args -p stamped:=true -p use_sim_time:=true`로 실행합니다. 17장의 Nav2 설정(`enable_stamped_cmd_vel`)도 함께 맞춰야 합니다.

</details>

## 6. 원서 대조 메모

- 원서의 TortoiseBot 치수와 URDF 값은 옮기지 않고, 17장의 Nav2 기본 설정(`robot_radius` 0.22 m 안팎)과 TurtleBot3 연습장에 맞게 새로 정했습니다. 그래서 이 가이드의 모델은 원서 그림과 비율이 다릅니다.
- 원서는 `urdf_tutorial` 패키지의 런치로 모델을 봅니다. 이 환경에는 `ros-jazzy-urdf-tutorial`이 설치되어 있지 않고, 16-4처럼 런치 파일을 직접 쓰는 편이 구조가 잘 보입니다.
- 원서의 Gazebo Classic 플러그인(diff drive, joint state)은 Gazebo Harmonic의 시스템 플러그인과 브리지 조합으로 바꿨습니다. 원서에는 브리지에 해당하는 단계가 없습니다. Gazebo Classic 플러그인이 ROS 토픽을 직접 냈기 때문입니다.
- 원서 PDF p.307: 캐스터 바퀴 위치를 설명하는 문장은 y와 z 방향으로 옮긴다고 쓰지만, 같은 쪽의 URDF 값은 x와 z를 옮깁니다.
- 원서 PDF p.302: 명령어 `roslaunch`의 철자가 틀린 곳이 있습니다.
- 원서는 로봇 기준 좌표계로 `base_link`만 씁니다. 이 가이드는 REP-105와 Nav2 기본 설정에 맞춰 `base_footprint`를 추가했습니다.

## 7. 이 문서의 검증 상태

- 확인함 (WSL Ubuntu 24.04, ROS 2 Jazzy, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`, 이 문서와 같은 파일을 별도 워크스페이스에서 빌드):
  - `apt-cache policy`: `ros-jazzy-joint-state-publisher-gui`만 미설치, 나머지 사용 패키지는 설치됨.
  - `colcon build` 성공, 설치 폴더에 launch, urdf, config, worlds 파일 복사.
  - `fake_base_driver`: Twist pub 후 `/odom` 위치 변화, `tf2_echo odom base_footprint`, `topic info -v /cmd_vel`.
  - 16-3, 16-4 모델: `xacro`와 `check_urdf` 트리 출력. 16-5: `gz sdf -k` Valid, `gz sdf -p`의 링크 목록(base_link 합쳐짐, revolute), `--inertial-stats` 전체 질량 1.5.
  - `robot_state_publisher`와 `joint_state_publisher`(GUI 없는 판): `/robot_description` TRANSIENT_LOCAL, `/joint_states` 이름 4개, `view_frames`로 `odom → base_footprint → base_link → 바퀴들` 트리.
  - `display.launch.py`, `sim.launch.py`: `--show-args`로 런치 파일이 읽히는지만 확인.
  - Gazebo 서버만(`gz sim -s -r --headless-rendering`, 창 없음) 띄우고 브리지와 `create -file`로 같은 모델을 넣어서: `/clock`, `/joint_states` 이름, 0.2 m/s Twist 약 6초 후 `/odom` x 약 1.30, `/cmd_vel` 구독자 `ros_gz_bridge`(Twist), TwistStamped pub이 구독자를 찾지 못함.
  - TurtleBot3 브리지 yaml의 `cmd_vel` 타입(`TwistStamped`), `teleop_twist_keyboard`의 `stamped` 파라미터 기본값 `false`.
- 확인 못 함:
  - rviz2, `joint_state_publisher_gui`, Gazebo 창 화면(GUI). `sim.launch.py` 자체는 창이 뜨므로 실행하지 않았고, 같은 구성 요소를 따로 띄워 확인했습니다.
  - 4절의 둘째, 셋째, 넷째, 다섯째, 여섯째 줄은 예상 증상이며 재현하지 않았습니다.
