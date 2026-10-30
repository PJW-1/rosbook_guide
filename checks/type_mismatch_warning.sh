#!/bin/bash
# 3장·21장·23장 4절: 같은 토픽에 타입이 다른 발행자와 구독자가 있을 때 경고가 찍히는가.
# rclpy 는 RMW 가 incompatible type 이벤트를 알려 주면 경고를 찍도록 되어 있으므로(event_handler.py),
# RMW 마다 실제로 경고가 나오는지 프로세스 둘과 한 프로세스에서 각각 확인합니다.
# 프로세스 둘일 때는 발행자와 구독자가 서로를 발견했는지(디스커버리)도 각 프로세스의 그래프 조회로 함께 확인합니다.
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
        self.seen = set()
        self.pub = self.create_publisher(String, 'tm', 10)
        self.timer = self.create_timer(0.2, self.tick)

    def tick(self):
        self.pub.publish(String(data='hi'))
        # 이 프로세스가 발견한 /tm 구독자의 타입을 모아 둡니다.
        self.seen.update(i.topic_type for i in self.get_subscriptions_info_by_topic('/tm'))


rclpy.init()
node = Pub()
try:
    rclpy.spin(node)
except (KeyboardInterrupt, ExternalShutdownException):
    pass
print(f'pub sees subscriptions={sorted(node.seen)}', flush=True)
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
        self.seen = set()
        self.sub = self.create_subscription(Int32, 'tm', self.on_msg, 10)
        self.timer = self.create_timer(0.2, self.look)

    def on_msg(self, msg):
        self.received += 1

    def look(self):
        # 이 프로세스가 발견한 /tm 발행자의 타입을 모아 둡니다.
        self.seen.update(i.topic_type for i in self.get_publishers_info_by_topic('/tm'))


rclpy.init()
node = Sub()
try:
    rclpy.spin(node)
except (KeyboardInterrupt, ExternalShutdownException):
    pass
print(f'sub sees publishers={sorted(node.seen)}', flush=True)
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
        print('both: publisher created', flush=True)
        self.sub = self.create_subscription(Int32, 'tm', lambda msg: None, 10)
        print('both: subscription created', flush=True)
        self.timer = self.create_timer(0.2, lambda: self.pub.publish(String(data='hi')))


rclpy.init()
try:
    rclpy.spin(Both())
except (KeyboardInterrupt, ExternalShutdownException):
    pass
EOF

for rmw in rmw_cyclonedds_cpp rmw_fastrtps_cpp; do
  run_bg "$CHECK_TMP/sub_$rmw.log" env RMW_IMPLEMENTATION=$rmw python3 "$CHECK_TMP/sub.py"
  run_bg "$CHECK_TMP/pub_$rmw.log" env RMW_IMPLEMENTATION=$rmw python3 "$CHECK_TMP/pub.py"
  sleep 10
  stop_bg
  w_sub=$(grep -ci "incompatible type" "$CHECK_TMP/sub_$rmw.log")
  w_pub=$(grep -ci "incompatible type" "$CHECK_TMP/pub_$rmw.log")
  got=$(grep -o "received=[0-9]*" "$CHECK_TMP/sub_$rmw.log")
  sub_seen=$(grep -o "sub sees publishers=.*" "$CHECK_TMP/sub_$rmw.log")
  pub_seen=$(grep -o "pub sees subscriptions=.*" "$CHECK_TMP/pub_$rmw.log")
  info "$rmw, 프로세스 둘: 구독 쪽 경고 ${w_sub}줄, 발행 쪽 경고 ${w_pub}줄, ${got:-received=?}"
  info "$rmw, 프로세스 둘: ${sub_seen:-sub sees ?}, ${pub_seen:-pub sees ?}"
  grep -ih "incompatible type" "$CHECK_TMP/sub_$rmw.log" "$CHECK_TMP/pub_$rmw.log" | head -2
  # 21장 실습 21-4 (1)이 적은 동작: 서로를 발견했는데도 경고 없이 한 건도 받지 못합니다.
  if [ "$sub_seen" = "sub sees publishers=['std_msgs/msg/String']" ] \
    && [ "$pub_seen" = "pub sees subscriptions=['std_msgs/msg/Int32']" ]; then
    pass "$rmw, 프로세스 둘: 발행자와 구독자가 서로를 발견함"
  else
    fail "$rmw, 프로세스 둘: 발행자와 구독자가 서로를 발견하지 못함"
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
  # 21장 7절이 적은 동작: Cyclone DDS 는 한 프로세스에서도 조용하고, Fast DDS 는 구독을 만드는 단계에서 오류를 냅니다.
  pub_made=$(grep -c "both: publisher created" "$CHECK_TMP/both_$rmw.log")
  sub_made=$(grep -c "both: subscription created" "$CHECK_TMP/both_$rmw.log")
  sub_err=$(grep -cF "create_subscription() called for existing topic name rt/tm with incompatible type" "$CHECK_TMP/both_$rmw.log")
  if [ "$rmw" = rmw_cyclonedds_cpp ]; then
    if [ "$pub_made" -eq 1 ] && [ "$sub_made" -eq 1 ] && [ "$w_both" -eq 0 ]; then
      pass "$rmw, 한 프로세스: 경고 없이 발행자와 구독을 모두 만듦"
    else
      fail "$rmw, 한 프로세스: 발행자 생성 ${pub_made}번, 구독 생성 ${sub_made}번, incompatible type ${w_both}줄"
    fi
  elif [ "$pub_made" -eq 1 ] && [ "$sub_made" -eq 0 ] && [ "$sub_err" -ge 1 ]; then
    pass "$rmw, 한 프로세스: 발행자는 만들고, 구독을 만드는 단계에서 incompatible type 오류"
  else
    fail "$rmw, 한 프로세스: 발행자 생성 ${pub_made}번, 구독 생성 ${sub_made}번, create_subscription 오류 ${sub_err}줄"
  fi
done
finish
