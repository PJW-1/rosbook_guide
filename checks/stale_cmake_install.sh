#!/bin/bash
# 23장 4절: CMakeLists.txt 에서 install(TARGETS ...) 를 지우고 다시 빌드하면 어떻게 되는가.
# --symlink-install 로 이미 빌드한 워크스페이스에서는 이전 링크가 install/ 에 남아 그대로 실행되고,
# 그 패키지의 build/ 와 install/ 을 지운 뒤 다시 빌드해야 No executable found 가 나오는지 확인합니다.
source "$(dirname "$0")/common.sh"

WS="$CHECK_TMP/ws"
PKG="$WS/src/basics_cpp"
mkdir -p "$PKG/src"
cat > "$PKG/package.xml" << 'EOF'
<?xml version="1.0"?>
<package format="3">
  <name>basics_cpp</name>
  <version>0.0.0</version>
  <description>check</description>
  <maintainer email="check@example.com">check</maintainer>
  <license>Apache-2.0</license>
  <buildtool_depend>ament_cmake</buildtool_depend>
  <export><build_type>ament_cmake</build_type></export>
</package>
EOF
cat > "$PKG/src/topic_publisher.cpp" << 'EOF'
#include <cstdio>

int main()
{
  std::puts("topic_publisher started");
  return 0;
}
EOF
write_cmake() {
  cat > "$PKG/CMakeLists.txt" << EOF
cmake_minimum_required(VERSION 3.8)
project(basics_cpp)
find_package(ament_cmake REQUIRED)
add_executable(topic_publisher src/topic_publisher.cpp)
$1
ament_package()
EOF
}
build() {
  (cd "$WS" && colcon build --symlink-install --packages-select basics_cpp) > "$CHECK_TMP/build.log" 2>&1
}
try_run() {
  (cd "$WS" && source install/setup.bash && timeout 20 ros2 run basics_cpp topic_publisher) \
    > "$CHECK_TMP/run.log" 2>&1
}

write_cmake 'install(TARGETS topic_publisher DESTINATION lib/${PROJECT_NAME})'
if ! build; then
  fail "첫 빌드 실패"
  cat "$CHECK_TMP/build.log"
  finish
  exit
fi
if try_run && grep -q "topic_publisher started" "$CHECK_TMP/run.log"; then
  pass "install 규칙이 있을 때 ros2 run 성공"
else
  fail "install 규칙이 있는데 ros2 run 실패"
  cat "$CHECK_TMP/run.log"
fi

write_cmake ''
build || fail "install 규칙을 지운 뒤 빌드 실패"
if try_run && grep -q "topic_publisher started" "$CHECK_TMP/run.log"; then
  pass "install 규칙을 지우고 같은 워크스페이스에서 다시 빌드만 하면 ros2 run 이 여전히 성공 (이전 링크가 남음)"
  ls -l "$WS/install/basics_cpp/lib/basics_cpp/"
else
  fail "install 규칙을 지우고 다시 빌드만 했는데 ros2 run 이 실패함"
  cat "$CHECK_TMP/run.log"
fi

rm -rf "$WS/build/basics_cpp" "$WS/install/basics_cpp"
build || fail "build/basics_cpp 와 install/basics_cpp 를 지운 뒤 빌드 실패"
if try_run; then
  fail "build/ 와 install/ 을 지우고 다시 빌드했는데도 ros2 run 이 성공함"
elif grep -q "No executable found" "$CHECK_TMP/run.log"; then
  pass "지우고 다시 빌드하면 No executable found"
  cat "$CHECK_TMP/run.log"
  ls -l "$WS/install/basics_cpp/lib/basics_cpp/" 2>&1
else
  fail "예상과 다른 실패"
  cat "$CHECK_TMP/run.log"
fi
finish
