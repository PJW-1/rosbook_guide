#!/bin/bash
# 3장 실습 3-7: ros2 topic pub -t 3 은 구독자가 연결될 때까지 기다렸다가 발행하는가.
# 구독자가 없으면 발행하지 않고 기다리는지, 구독자가 있으면 세 메시지가 모두 도착하는지 확인합니다.
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=62
start_daemon

timeout 5 ros2 topic pub -t 3 /number std_msgs/msg/Int32 "{data: 21}" > "$CHECK_TMP/no_sub.log" 2>&1
rc=$?
cat "$CHECK_TMP/no_sub.log"
if [ "$rc" -eq 124 ] && grep -q "Waiting for at least 1 matching subscription" "$CHECK_TMP/no_sub.log"; then
  pass "구독자가 없으면 -t 3 은 발행하지 않고 기다림"
else
  fail "구독자가 없을 때 rc=$rc"
fi

for trial in 1 2 3; do
  run_bg "$CHECK_TMP/echo_$trial.log" ros2 topic echo /number std_msgs/msg/Int32
  sleep 2
  timeout 20 ros2 topic pub -t 3 /number std_msgs/msg/Int32 "{data: 21}" > "$CHECK_TMP/pub_$trial.log" 2>&1
  sleep 1
  stop_bg
  n=$(grep -c "data: 21" "$CHECK_TMP/echo_$trial.log")
  if [ "$n" -eq 3 ]; then
    pass "시도 $trial: 구독자가 있으면 세 메시지가 모두 도착"
  else
    fail "시도 $trial: 도착한 메시지 ${n}개"
  fi
done
cat "$CHECK_TMP/pub_1.log"
finish
