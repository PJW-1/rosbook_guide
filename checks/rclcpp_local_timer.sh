#!/bin/bash
# 3장 Q1, 23장 4절: C++ 노드에서 타이머를 멤버 변수에 담지 않으면 어떻게 되는가.
# 생성자의 지역 변수로 받은 타이머는 생성자가 끝날 때 사라져서 콜백이 한 번도 불리지 않는지,
# 멤버 변수에 담으면 계속 불리는지 비교합니다.
source "$(dirname "$0")/common.sh"
export ROS_DOMAIN_ID=63

WS="$CHECK_TMP/ws"
PKG="$WS/src/timer_check"
mkdir -p "$PKG/src"
cat > "$PKG/package.xml" << 'EOF'
<?xml version="1.0"?>
<package format="3">
  <name>timer_check</name>
  <version>0.0.0</version>
  <description>check</description>
  <maintainer email="check@example.com">check</maintainer>
  <license>Apache-2.0</license>
  <buildtool_depend>ament_cmake</buildtool_depend>
  <depend>rclcpp</depend>
  <export><build_type>ament_cmake</build_type></export>
</package>
EOF
cat > "$PKG/CMakeLists.txt" << 'EOF'
cmake_minimum_required(VERSION 3.8)
project(timer_check)
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
add_executable(timer_node src/timer_node.cpp)
target_link_libraries(timer_node rclcpp::rclcpp)
install(TARGETS timer_node DESTINATION lib/${PROJECT_NAME})
ament_package()
EOF
cat > "$PKG/src/timer_node.cpp" << 'EOF'
#include <chrono>
#include <memory>
#include <string>

#include "rclcpp/rclcpp.hpp"

using namespace std::chrono_literals;

class TimerNode : public rclcpp::Node
{
public:
  explicit TimerNode(bool keep)
  : Node("timer_check")
  {
    auto timer = create_wall_timer(200ms, [this]() {RCLCPP_INFO(get_logger(), "tick");});
    if (keep) {
      timer_ = timer;
    }
  }

private:
  rclcpp::TimerBase::SharedPtr timer_;
};

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  bool keep = argc > 1 && std::string(argv[1]) == "member";
  rclcpp::spin(std::make_shared<TimerNode>(keep));
  rclcpp::shutdown();
  return 0;
}
EOF

if ! (cd "$WS" && colcon build --symlink-install) > "$CHECK_TMP/build.log" 2>&1; then
  fail "빌드 실패"
  tail -20 "$CHECK_TMP/build.log"
  finish
  exit
fi
source "$WS/install/setup.bash"

timeout -s INT 3 ros2 run timer_check timer_node member > "$CHECK_TMP/member.log" 2>&1
member=$(grep -c "tick" "$CHECK_TMP/member.log")
timeout -s INT 3 ros2 run timer_check timer_node local > "$CHECK_TMP/local.log" 2>&1
local_rc=$?
local_ticks=$(grep -c "tick" "$CHECK_TMP/local.log")

if [ "$member" -ge 8 ]; then
  pass "타이머를 멤버 변수에 담으면 3초 동안 tick ${member}번"
else
  fail "멤버 변수 타이머의 tick 이 ${member}번뿐"
  cat "$CHECK_TMP/member.log"
fi
# timeout 이 끝까지 기다렸다가 멈췄으면 124 이므로, 노드가 3초 동안 떠 있었다는 뜻입니다.
if [ "$local_ticks" -eq 0 ] && [ "$local_rc" -eq 124 ]; then
  pass "타이머를 생성자의 지역 변수로만 받으면 tick 0번 (노드는 3초 동안 떠 있었음)"
else
  fail "지역 변수 타이머: tick ${local_ticks}번, rc=$local_rc"
fi
finish
