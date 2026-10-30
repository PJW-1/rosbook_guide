#!/bin/bash
# 3장·21장·23장 4절: 같은 토픽에 타입이 다른 발행자와 구독자가 있을 때 경고가 찍히는가.
# rclpy 는 RMW 가 incompatible type 이벤트를 알려 주면 경고를 찍도록 되어 있으므로(event_handler.py),
# RMW 마다 실제로 경고가 나오는지 프로세스 둘과 한 프로세스에서 각각 확인합니다.
# 프로세스 둘일 때는 서로를 발견했는지(디스커버리)도 그래프 조회로 함께 확인합니다.
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=61

cat > "$CHECK_TMP/pub.py" << 'EOF'
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import String


class Pub(Node):
    def __init__(self):
        super().__init__('tm_pub')
        self.pub = self.create_publisher(String, 'tm', 10)
        self.timer = self.create_timer(0.2, lambda: self.pub.publish(String(data='hi')))


rclpy.init()
try:
    rclpy.spin(Pub())
except (KeyboardInterrupt, ExternalShutdownException):
    pass
EOF
cat > "$CHECK_TMP/sub.py" << 'EOF'
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import Int32


class Sub(Node):
    def __init__(self):
        super().__init__('tm_sub')
        self.received = 0
        self.sub = self.create_subscription(Int32, 'tm', self.on_msg, 10)

    def on_msg(self, msg):
        self.received += 1


rclpy.init()
node = Sub()
try:
    rclpy.spin(node)
except (KeyboardInterrupt, ExternalShutdownException):
    pass
print(f'received={node.received}', flush=True)
EOF
cat > "$CHECK_TMP/both.py" << 'EOF'
import rclpy
from rclpy.executors import ExternalShutdownException
from rclpy.node import Node
from std_msgs.msg import Int32, String


class Both(Node):
    def __init__(self):
        super().__init__('tm_both')
        self.pub = self.create_publisher(String, 'tm', 10)
        self.sub = self.create_subscription(Int32, 'tm', lambda msg: None, 10)
        self.timer = self.create_timer(0.2, lambda: self.pub.publish(String(data='hi')))


rclpy.init()
try:
    rclpy.spin(Both())
except (KeyboardInterrupt, ExternalShutdownException):
    pass
EOF
cat > "$CHECK_TMP/graph.py" << 'EOF'
import time

import rclpy
from rclpy.node import Node

rclpy.init()
node = Node('tm_graph')
end = time.monotonic() + 3.0
while time.monotonic() < end:
    rclpy.spin_once(node, timeout_sec=0.1)
pubs = [i.topic_type for i in node.get_publishers_info_by_topic('/tm')]
subs = [i.topic_type for i in node.get_subscriptions_info_by_topic('/tm')]
print(f'graph: publishers={pubs} subscriptions={subs}', flush=True)
EOF

for rmw in rmw_cyclonedds_cpp rmw_fastrtps_cpp; do
  run_bg "$CHECK_TMP/sub_$rmw.log" env RMW_IMPLEMENTATION=$rmw python3 "$CHECK_TMP/sub.py"
  run_bg "$CHECK_TMP/pub_$rmw.log" env RMW_IMPLEMENTATION=$rmw python3 "$CHECK_TMP/pub.py"
  sleep 3
  graph=$(timeout 20 env RMW_IMPLEMENTATION=$rmw python3 "$CHECK_TMP/graph.py" 2>&1)
  sleep 3
  stop_bg
  w_sub=$(grep -ci "incompatible type" "$CHECK_TMP/sub_$rmw.log")
  w_pub=$(grep -ci "incompatible type" "$CHECK_TMP/pub_$rmw.log")
  got=$(grep -o "received=[0-9]*" "$CHECK_TMP/sub_$rmw.log")
  info "$rmw, 프로세스 둘: 구독 쪽 경고 ${w_sub}줄, 발행 쪽 경고 ${w_pub}줄, ${got:-received=?}"
  info "$rmw, 프로세스 둘의 $graph"
  grep -ih "incompatible type" "$CHECK_TMP/sub_$rmw.log" "$CHECK_TMP/pub_$rmw.log" | head -2
  # 21장 실습 21-4 (1)이 적은 동작: 서로를 발견했는데도 경고 없이 한 건도 받지 못합니다.
  if echo "$graph" | grep -q "publishers=\['std_msgs/msg/String'\] subscriptions=\['std_msgs/msg/Int32'\]"; then
    pass "$rmw, 프로세스 둘: 그래프에 두 타입이 모두 보임 (서로를 발견함)"
  else
    fail "$rmw, 프로세스 둘: 그래프 조회 결과가 예상과 다름"
  fi
  if [ "$w_sub" -eq 0 ] && [ "$w_pub" -eq 0 ] && [ "$got" = "received=0" ]; then
    pass "$rmw, 프로세스 둘: 경고 없이 한 건도 받지 못함"
  else
    fail "$rmw, 프로세스 둘: 경고 ${w_sub}/${w_pub}줄, ${got:-received=?}"
  fi

  run_bg "$CHECK_TMP/both_$rmw.log" env RMW_IMPLEMENTATION=$rmw python3 "$CHECK_TMP/both.py"
  sleep 4
  stop_bg
  w_both=$(grep -ci "incompatible type" "$CHECK_TMP/both_$rmw.log")
  info "$rmw, 한 프로세스: incompatible type 이 들어간 줄 ${w_both}개"
  grep -ih "incompatible type" "$CHECK_TMP/both_$rmw.log" | head -2
done
finish
