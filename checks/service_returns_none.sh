#!/bin/bash
# 4장 Q2: 서비스 콜백이 응답을 돌려주지 않으면(None) 어떻게 되는가.
# rclpy 의 send_response 는 응답 타입이 아니면 TypeError 를 던집니다(service.py).
# 이 예외가 rclpy.spin 밖으로 나와 서버 프로세스가 끝나는지, 클라이언트는 응답을 못 받는지 확인합니다.
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=65

cat > "$CHECK_TMP/server.py" << 'EOF'
import rclpy
from example_interfaces.srv import AddTwoInts
from rclpy.node import Node


class NoneServer(Node):
    def __init__(self):
        super().__init__('none_server')
        self.srv = self.create_service(AddTwoInts, 'add_two_ints', self.callback)

    def callback(self, request, response):
        self.get_logger().info('callback returns None')


rclpy.init()
rclpy.spin(NoneServer())
EOF

run_bg "$CHECK_TMP/server.log" python3 "$CHECK_TMP/server.py"
server_pid=${BG_PIDS[0]}
sleep 2
timeout 10 ros2 service call /add_two_ints example_interfaces/srv/AddTwoInts "{a: 1, b: 2}" \
  > "$CHECK_TMP/call.log" 2>&1
rc=$?
echo "--- 서버 출력"
cat "$CHECK_TMP/server.log"
echo "--- 클라이언트 출력"
cat "$CHECK_TMP/call.log"

if grep -q "TypeError" "$CHECK_TMP/server.log"; then
  pass "서버가 TypeError 트레이스백을 남김"
else
  fail "서버 출력에 TypeError 가 없음"
fi
if kill -0 "$server_pid" 2> /dev/null; then
  fail "서버 프로세스가 아직 살아 있음"
else
  pass "서버 프로세스가 끝남"
fi
if [ "$rc" -eq 124 ]; then
  pass "ros2 service call 은 응답을 받지 못하고 10초 동안 기다림"
else
  fail "ros2 service call rc=$rc"
fi
finish
