#!/bin/bash
# 5장 Q2, Q5: rclpy.spin() 하나로 돌고 execute 가 time.sleep() 으로 기다리는 단순 액션 서버(실습 5-2 와 같은 구조).
# Q2: goal 두 개를 겹쳐 보내면 두 번째는 첫 번째가 끝난 뒤에 시작하는지 확인합니다.
# Q5: 클라이언트가 취소 없이 꺼져도 서버의 goal 은 끝까지 실행되는지 확인합니다.
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=67

cat > "$CHECK_TMP/server.py" << 'EOF'
import time

from example_interfaces.action import Fibonacci
import rclpy
from rclpy.action import ActionServer
from rclpy.node import Node


class SimpleServer(Node):
    def __init__(self):
        super().__init__('simple_check_server')
        self.server = ActionServer(self, Fibonacci, 'fib', self.execute)

    def execute(self, goal_handle):
        order = goal_handle.request.order
        self.get_logger().info(f'start {order}')
        time.sleep(2.0)
        goal_handle.succeed()
        self.get_logger().info(f'done {order}')
        return Fibonacci.Result()


rclpy.init()
try:
    rclpy.spin(SimpleServer())
except KeyboardInterrupt:
    pass
EOF
cat > "$CHECK_TMP/two_goals.py" << 'EOF'
import time

from example_interfaces.action import Fibonacci
import rclpy
from rclpy.action import ActionClient
from rclpy.node import Node

rclpy.init()
node = Node('two_goals_client')
client = ActionClient(node, Fibonacci, 'fib')
client.wait_for_server(timeout_sec=10.0)
start = time.monotonic()
sends = [client.send_goal_async(Fibonacci.Goal(order=n)) for n in (1, 2)]
for f in sends:
    rclpy.spin_until_future_complete(node, f)
results = [f.result().get_result_async() for f in sends]
for n, f in zip((1, 2), results):
    rclpy.spin_until_future_complete(node, f)
    print(f'goal {n}: status={f.result().status} at {time.monotonic() - start:.1f}s', flush=True)
EOF
cat > "$CHECK_TMP/one_goal.py" << 'EOF'
import time

from example_interfaces.action import Fibonacci
import rclpy
from rclpy.action import ActionClient
from rclpy.node import Node

rclpy.init()
node = Node('orphan_client')
client = ActionClient(node, Fibonacci, 'fib')
client.wait_for_server(timeout_sec=10.0)
send_future = client.send_goal_async(Fibonacci.Goal(order=7))
rclpy.spin_until_future_complete(node, send_future)
print('accepted', flush=True)
time.sleep(30)
EOF

run_bg "$CHECK_TMP/server.log" python3 "$CHECK_TMP/server.py"
sleep 2
out=$(timeout 30 python3 "$CHECK_TMP/two_goals.py" 2>&1)
echo "$out"
order=$(grep -o "start [12]\|done [12]" "$CHECK_TMP/server.log" | tr '\n' ' ')
echo "서버 순서: $order"
if [ "$order" = "start 1 done 1 start 2 done 2 " ] && [ "$(echo "$out" | grep -c "status=4")" -eq 2 ]; then
  pass "Q2: 두 번째 goal 은 첫 번째가 끝난 뒤에 시작하고 둘 다 SUCCEEDED"
else
  fail "Q2: 예상과 다른 순서 또는 상태"
fi

timeout -s INT 1.5 python3 "$CHECK_TMP/one_goal.py" > "$CHECK_TMP/orphan.log" 2>&1
grep -q accepted "$CHECK_TMP/orphan.log" && info "Q5: 클라이언트가 goal 을 보낸 뒤 취소 없이 Ctrl+C 로 꺼짐"
sleep 3
if grep -q "done 7" "$CHECK_TMP/server.log"; then
  pass "Q5: 클라이언트가 꺼진 뒤에도 서버는 goal 을 끝까지 실행함"
else
  fail "Q5: 서버 로그에 done 7 이 없음"
fi
cat "$CHECK_TMP/server.log"
finish
