#!/bin/bash
# 2장·20장 4절: setup.py 에서 launch 파일의 data_files 줄을 지우고 다시 빌드하면 어떻게 되는가.
# --symlink-install 로 이미 빌드한 워크스페이스에서는 이전 링크가 install/ 에 남아 그대로 실행되고,
# 그 패키지의 build/ 와 install/ 을 지운 뒤 다시 빌드해야 launch 파일을 찾지 못하는지 확인합니다.
source "$(dirname "$0")/common.sh"

WS="$CHECK_TMP/ws"
PKG="$WS/src/basics"
mkdir -p "$PKG/basics" "$PKG/launch" "$PKG/resource"
touch "$PKG/basics/__init__.py" "$PKG/resource/basics"
cat > "$PKG/package.xml" << 'EOF'
<?xml version="1.0"?>
<package format="3">
  <name>basics</name>
  <version>0.0.0</version>
  <description>check</description>
  <maintainer email="check@example.com">check</maintainer>
  <license>Apache-2.0</license>
  <export><build_type>ament_python</build_type></export>
</package>
EOF
cat > "$PKG/setup.py" << 'EOF'
from glob import glob

from setuptools import setup

package_name = 'basics'

setup(
    name=package_name,
    version='0.0.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages', ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        ('share/' + package_name + '/launch', glob('launch/*.launch.py')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
)
EOF
cat > "$PKG/setup.cfg" << 'EOF'
[develop]
script_dir=$base/lib/basics
[install]
install_scripts=$base/lib/basics
EOF
cat > "$PKG/launch/talker_listener.launch.py" << 'EOF'
from launch import LaunchDescription


def generate_launch_description():
    return LaunchDescription([])
EOF

build() {
  (cd "$WS" && colcon build --symlink-install --packages-select basics) > "$CHECK_TMP/build.log" 2>&1
}
try_launch() {
  (cd "$WS" && source install/setup.bash && timeout 30 ros2 launch basics talker_listener.launch.py) \
    > "$CHECK_TMP/launch.log" 2>&1
}

if ! build; then
  fail "첫 빌드 실패"
  cat "$CHECK_TMP/build.log"
  finish
  exit
fi
if try_launch; then
  pass "data_files 줄이 있을 때 ros2 launch 성공"
else
  fail "data_files 줄이 있는데 ros2 launch 실패"
fi

sed -i "/launch\/\*\.launch\.py/d" "$PKG/setup.py"
build || fail "줄을 지운 뒤 빌드 실패"
if try_launch; then
  pass "줄을 지우고 같은 워크스페이스에서 다시 빌드만 하면 ros2 launch 가 여전히 성공 (이전 링크가 남음)"
  ls -l "$WS/install/basics/share/basics/launch/"
else
  fail "줄을 지우고 다시 빌드만 했는데 ros2 launch 가 실패함"
  cat "$CHECK_TMP/launch.log"
fi

rm -rf "$WS/build/basics" "$WS/install/basics"
build || fail "build/basics 와 install/basics 를 지운 뒤 빌드 실패"
if try_launch; then
  fail "build/ 와 install/ 을 지우고 다시 빌드했는데도 ros2 launch 가 성공함"
elif grep -q "was not found in the share directory of package 'basics'" "$CHECK_TMP/launch.log"; then
  pass "지우고 다시 빌드하면 launch 파일을 찾지 못함"
  grep -m1 "was not found" "$CHECK_TMP/launch.log"
  ls "$WS/install/basics/share/basics/"
else
  fail "예상과 다른 실패"
  cat "$CHECK_TMP/launch.log"
fi
finish
