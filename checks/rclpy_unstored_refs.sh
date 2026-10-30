#!/bin/bash
# 3장 2절, 실습 3-1 해설, Q1: rclpy 에서 create_timer 와 create_subscription 의 반환값을
# self 에 담지 않아도 타이머와 구독이 계속 동작하는지 확인합니다. 가비지 컬렉션을 계속 돌려도 같은지 봅니다.
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=64

cat > "$CHECK_TMP/ref_check.py" << 'EOF'
import gc
import time

import rclpy
from rclpy.node import Node
from std_msgs.msg import Int32


class RefCheck(Node):
    def __init__(self):
        super().__init__('ref_check')
        self.ticks = 0
        self.received = 0
        self.pub = self.create_publisher(Int32, 'ref_check', 10)
        # 반환값을 self 에 담지 않습니다.
        self.create_timer(0.1, self.tick)
        self.create_subscription(Int32, 'ref_check', self.on_msg, 10)

    def tick(self):
        self.ticks += 1
        self.pub.publish(Int32(data=self.ticks))

    def on_msg(self, msg):
        self.received += 1


rclpy.init()
node = RefCheck()
gc.collect()
end = time.monotonic() + 2.0
while time.monotonic() < end:
    rclpy.spin_once(node, timeout_sec=0.05)
    gc.collect()
print(f'ticks={node.ticks} received={node.received} '
      f'timers={len(list(node.timers))} subscriptions={len(list(node.subscriptions))}')
node.destroy_node()
rclpy.shutdown()
EOF

out=$(timeout 30 python3 "$CHECK_TMP/ref_check.py" 2>&1)
echo "$out"
ticks=$(echo "$out" | sed -n 's/.*ticks=\([0-9]*\).*/\1/p')
received=$(echo "$out" | sed -n 's/.*received=\([0-9]*\).*/\1/p')
if [ "${ticks:-0}" -ge 15 ]; then
  pass "self 에 담지 않은 타이머가 2초 동안 ${ticks}번 불림"
else
  fail "타이머가 ${ticks:-0}번만 불림"
fi
if [ "${received:-0}" -ge 10 ]; then
  pass "self 에 담지 않은 구독이 ${received}개를 받음"
else
  fail "구독이 ${received:-0}개만 받음"
fi
finish
