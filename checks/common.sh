# 주장 확인 스크립트의 공통 설정입니다. 각 스크립트가 맨 앞에서 source 합니다.
# 작업 폴더는 /tmp 아래에 새로 만들고 끝날 때 지우므로 ~/rosbook_ws 는 건드리지 않습니다.
source /opt/ros/jazzy/setup.bash
export RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}"
export RCUTILS_LOGGING_BUFFERED_STREAM=0
# 실행 중인 다른 노드와 섞이지 않도록 기본 도메인을 피합니다. 노드를 띄우는 스크립트는 각자 다른 번호로 다시 정합니다.
export ROS_DOMAIN_ID=56
CHECK_TMP="$(mktemp -d /tmp/rosbook_check.XXXXXX)"
export ROS_LOG_DIR="$CHECK_TMP/ros_log"
FAILS=0
BG_PIDS=()
DAEMON_STARTED=0

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }
info() { echo "INFO: $*"; }

# 백그라운드 프로세스는 새 프로세스 그룹으로 띄우고, 끝날 때 그룹째 끕니다.
run_bg() {
  local log="$1"
  shift
  setsid "$@" > "$log" 2>&1 &
  BG_PIDS+=("$!")
}

# daemon 은 띄운 폴더를 계속 잡고 있으므로 홈에서 띄웁니다.
# 이미 떠 있던 daemon 은 다른 곳에서 쓰고 있을 수 있으므로, 이 스크립트가 띄운 경우에만 끝날 때 끕니다.
start_daemon() {
  (cd ~ && ros2 daemon start > "$CHECK_TMP/daemon_start.log" 2>&1)
  if grep -q "The daemon has been started" "$CHECK_TMP/daemon_start.log"; then
    DAEMON_STARTED=1
  fi
}

# 지금까지 띄운 백그라운드 프로세스를 모두 끕니다. Ctrl+C 와 같은 SIGINT 를 먼저 보냅니다.
stop_bg() {
  local pid
  for pid in "${BG_PIDS[@]}"; do
    kill -INT -- "-$pid" 2> /dev/null
  done
  sleep 1
  for pid in "${BG_PIDS[@]}"; do
    kill -KILL -- "-$pid" 2> /dev/null
  done
  BG_PIDS=()
}

cleanup() {
  stop_bg
  if [ "$DAEMON_STARTED" = 1 ]; then
    (cd ~ && timeout 20 ros2 daemon stop > /dev/null 2>&1)
  fi
  rm -rf "$CHECK_TMP"
}
trap cleanup EXIT

finish() {
  if [ "$FAILS" -eq 0 ]; then
    echo "ALL PASS"
  else
    echo "$FAILS FAILED"
  fi
  [ "$FAILS" -eq 0 ]
}
