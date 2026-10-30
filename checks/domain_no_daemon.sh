#!/bin/bash
# 1장·2장 4절: 다른 도메인의 노드를 ros2 node list 로 볼 때 --no-daemon 이 필요한가.
# daemon 이 없는 도메인에서 --no-daemon 을 붙이면 바로 끝나는지 확인하고,
# 붙이지 않았을 때 이 PC(WSL mirrored)에서 멈추는지 함께 기록합니다.
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=57

# 도메인 57 의 daemon 프로세스 번호를 출력합니다.
# daemon 의 명령줄에는 --name ros2-daemon 과 --ros-domain-id 57 이 붙습니다(ros2cli/daemon/daemonize.py).
daemon_pids() {
  local p cmd
  for p in /proc/[0-9]*; do
    cmd=$(tr '\0' ' ' < "$p/cmdline" 2> /dev/null)
    if [[ "$cmd" == *"--name ros2-daemon "* && "$cmd" == *"--ros-domain-id 57 "* ]]; then
      echo "${p#/proc/}"
    fi
  done
}
# --no-daemon 없이 실행하는 명령에만 ROSBOOK_CHECK_OWNER 를 붙입니다. 그 명령이 daemon 을 띄우면 daemon 이
# 이 환경 변수를 물려받으므로, 끝날 때(중간에 멈춰도) 이 표시가 있는 daemon 만 끕니다. 다른 곳에서 띄운 daemon 은 그대로 둡니다.
stop_own_daemons() {
  local pid
  for pid in $(daemon_pids); do
    if tr '\0' '\n' < "/proc/$pid/environ" 2> /dev/null | grep -qx "ROSBOOK_CHECK_OWNER=$$"; then
      kill "$pid"
    fi
  done
}
trap 'stop_own_daemons; cleanup' EXIT

if [ -n "$(daemon_pids)" ]; then
  info "도메인 57 에 이미 daemon 이 있으므로, --no-daemon 없이 실행한 결과는 daemon 이 없을 때의 동작이 아님"
fi

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
ROSBOOK_CHECK_OWNER=$$ timeout 20 ros2 node list > "$CHECK_TMP/daemon_path.log" 2>&1
rc=$?
elapsed=$(($(date +%s) - start))
if [ "$rc" -eq 124 ]; then
  info "--no-daemon 없이 실행하면 20초 안에 끝나지 않음 (이 PC 의 daemon 증상)"
else
  info "--no-daemon 없이 실행한 명령이 ${elapsed}초 만에 끝남 (rc=$rc)"
fi

finish
