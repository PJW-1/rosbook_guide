#!/bin/bash
# 2장 실습 2-10: composition 데모 컴포넌트 두 개를 컨테이너 하나에 올렸을 때 보이는 것을 확인합니다.
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=59
start_daemon

run_bg "$CHECK_TMP/container.log" ros2 run rclcpp_components component_container
sleep 3

echo "--- ros2 component types (composition 부분)"
ros2 component types | sed -n '/^composition$/,/^[^ ]/p'
echo "--- ros2 component list (load 전)"
ros2 component list
echo "--- load"
ros2 component load /ComponentManager composition composition::Talker
ros2 component load /ComponentManager composition composition::Listener
sleep 3
echo "--- ros2 component list"
list_out=$(ros2 component list)
echo "$list_out"
echo "--- ros2 node list"
nodes_out=$(ros2 node list)
echo "$nodes_out"
echo "--- 컨테이너 터미널 출력 앞부분"
head -6 "$CHECK_TMP/container.log"
echo "--- 프로세스"
procs=$(pgrep -af "component_container|talker|listener" | grep -v pgrep)
echo "$procs"

if echo "$list_out" | grep -q "/talker" && echo "$list_out" | grep -q "/listener"; then
  pass "ros2 component list 에 /talker 와 /listener 가 컨테이너 아래로 보임"
else
  fail "ros2 component list 에 두 컴포넌트가 없음"
fi
if grep -q "I heard" "$CHECK_TMP/container.log"; then
  pass "listener 컴포넌트가 talker 컴포넌트의 메시지를 받음"
else
  fail "컨테이너 출력에 I heard 가 없음"
fi
if echo "$procs" | grep -v component_container | grep -q .; then
  fail "talker 나 listener 가 별도 프로세스로 떠 있음"
else
  pass "talker 와 listener 는 별도 프로세스가 아님 (컨테이너 프로세스 하나)"
fi

echo "--- unload 1"
ros2 component unload /ComponentManager 1
sleep 1
ros2 component list
ros2 node list
finish
