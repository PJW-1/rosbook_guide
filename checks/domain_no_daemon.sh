#!/bin/bash
# 1장·2장 4절: 다른 도메인의 노드를 ros2 node list 로 볼 때 --no-daemon 이 필요한가.
# daemon 이 없는 도메인에서 --no-daemon 을 붙이면 바로 끝나는지 확인하고,
# 붙이지 않았을 때 이 PC(WSL mirrored)에서 멈추는지 함께 기록합니다.
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=57

run_bg "$CHECK_TMP/listener.log" ros2 run demo_nodes_py listener
sleep 3

start=$(date +%s)
out=$(timeout 30 ros2 node list --no-daemon 2>&1)
rc=$?
elapsed=$(($(date +%s) - start))
echo "$out"
if [ "$rc" -eq 0 ] && echo "$out" | grep -qx "/listener"; then
  pass "ROS_DOMAIN_ID=57 ros2 node list --no-daemon 이 ${elapsed}초 만에 /listener 를 보여 줌"
else
  fail "--no-daemon 결과 rc=$rc, ${elapsed}초"
fi

start=$(date +%s)
timeout 20 ros2 node list > "$CHECK_TMP/daemon_path.log" 2>&1
rc=$?
elapsed=$(($(date +%s) - start))
if [ "$rc" -eq 124 ]; then
  info "--no-daemon 없이 실행하면 20초 안에 끝나지 않음 (이 PC 의 daemon 증상)"
else
  info "--no-daemon 없이 실행한 명령이 ${elapsed}초 만에 끝남 (rc=$rc)"
fi

# --no-daemon 없이 실행한 명령이 도메인 57 의 daemon 을 띄웠다면 끕니다.
for p in /proc/[0-9]*; do
  if tr '\0' ' ' < "$p/cmdline" 2> /dev/null | grep -q "_ros2_daemon" \
    && tr '\0' '\n' < "$p/environ" 2> /dev/null | grep -qx "ROS_DOMAIN_ID=57"; then
    kill "${p#/proc/}"
  fi
done
finish
