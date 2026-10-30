#!/bin/bash
# 5장 Q4: 취소 콜백이 REJECT 를 돌려주거나 취소 콜백을 아예 주지 않으면 어떻게 되는가.
# 여러 스레드로 도는 서버(실습 5-4 와 같은 구조)에 goal 을 보낸 뒤 취소를 요청하고,
# 취소 응답(goals_canceling, return_code)과 최종 상태, 서버 쪽 is_cancel_requested 를 확인합니다.
# 비교용 accept 는 취소를 수락하지만 canceled() 를 부르지 않는 서버입니다(5장 실습 5-4 52~56줄 해설).
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=66

cat > "$CHECK_TMP/server.py" << 'EOF'
import sys
import time

from example_interfaces.action import Fibonacci
import rclpy
from rclpy.action import ActionServer, CancelResponse
from rclpy.callback_groups import ReentrantCallbackGroup
from rclpy.executors import MultiThreadedExecutor
from rclpy.node import Node


class Server(Node):
    def __init__(self, mode):
        super().__init__('cancel_check_server')
        kwargs = {}
        if mode == 'reject':
            kwargs['cancel_callback'] = lambda request: CancelResponse.REJECT
        elif mode == 'accept':
            kwargs['cancel_callback'] = lambda request: CancelResponse.ACCEPT
        self.server = ActionServer(
            self, Fibonacci, 'fib', self.execute,
            callback_group=ReentrantCallbackGroup(), **kwargs)

    def execute(self, goal_handle):
        for _ in range(20):
            if goal_handle.is_cancel_requested:
                self.get_logger().info('cancel requested seen')
            time.sleep(0.1)
        self.get_logger().info(f'finish: is_cancel_requested={goal_handle.is_cancel_requested}')
        goal_handle.succeed()
        return Fibonacci.Result()


rclpy.init()
executor = MultiThreadedExecutor()
executor.add_node(Server(sys.argv[1]))
try:
    executor.spin()
except KeyboardInterrupt:
    pass
EOF
cat > "$CHECK_TMP/client.py" << 'EOF'
import time

from example_interfaces.action import Fibonacci
import rclpy
from rclpy.action import ActionClient
from rclpy.node import Node

rclpy.init()
node = Node('cancel_check_client')
client = ActionClient(node, Fibonacci, 'fib')
client.wait_for_server(timeout_sec=10.0)
send_future = client.send_goal_async(Fibonacci.Goal(order=1))
rclpy.spin_until_future_complete(node, send_future)
goal_handle = send_future.result()
time.sleep(0.5)
cancel_future = goal_handle.cancel_goal_async()
rclpy.spin_until_future_complete(node, cancel_future)
cancel_response = cancel_future.result()
print(f'cancel return_code={cancel_response.return_code} '
      f'goals_canceling={len(cancel_response.goals_canceling)}')
result_future = goal_handle.get_result_async()
rclpy.spin_until_future_complete(node, result_future)
print(f'result status={result_future.result().status}')
EOF

for mode in reject default accept; do
  run_bg "$CHECK_TMP/server_$mode.log" python3 "$CHECK_TMP/server.py" "$mode"
  sleep 2
  out=$(timeout 30 python3 "$CHECK_TMP/client.py" 2>&1)
  sleep 1
  stop_bg
  echo "--- $mode: 클라이언트"
  echo "$out"
  echo "--- $mode: 서버"
  cat "$CHECK_TMP/server_$mode.log"
  # rclpy 서버는 거절한 goal 을 goals_canceling 에서 빼기만 하고 return_code 는 0(ERROR_NONE)으로 둡니다.
  # GoalStatus 4 = SUCCEEDED
  if [ "$mode" = accept ]; then
    expected="cancel return_code=0 goals_canceling=1"
    seen=True
  else
    expected="cancel return_code=0 goals_canceling=0"
    seen=False
  fi
  if echo "$out" | grep -q "$expected" && echo "$out" | grep -q "result status=4"; then
    pass "$mode: 취소 응답 '$expected', 최종 상태 SUCCEEDED(4)"
  else
    fail "$mode: 예상과 다른 응답"
  fi
  if grep -q "finish: is_cancel_requested=$seen" "$CHECK_TMP/server_$mode.log"; then
    pass "$mode: 서버의 is_cancel_requested 는 마지막에 $seen"
  else
    fail "$mode: 서버의 is_cancel_requested 가 예상과 다름"
  fi
done
finish
