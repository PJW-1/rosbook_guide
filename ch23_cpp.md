# 23장. ROS 2에서 C++ 쓰기

- 원서: Chapter 23. Using C++ in ROS, PDF p.425~435 (인쇄 쪽 = PDF 쪽 - 20)
- 선행 조건: 3장의 `basics` 패키지(`topic_publisher`, `topic_subscriber`), 4장의 `basics_interfaces` 패키지(`WordCount.srv`), 20장의 colcon 빌드와 `ros2 run`
- 새로 설치할 것: 없음 (C++ 컴파일러와 rclcpp는 ROS 2 desktop 설치에 들어 있습니다)

## 이 장에서 체감할 구조

노드가 어떤 언어로 쓰였는지는 토픽과 서비스 너머에서 보이지 않습니다. 같은 메시지 정의(`.msg`, `.srv`)에서 Python 코드와 C++ 코드가 함께 생성되기 때문입니다.
C++ 패키지는 `CMakeLists.txt` 에서 "무엇을 컴파일하고, 무엇과 링크하고, 어디에 설치할지"를 직접 적어야 합니다.
그래서 소스를 고칠 때마다 다시 빌드해야 하고, `--symlink-install` 도 C++ 소스 수정을 바로 반영해 주지는 않습니다.

## 1. 목표와 개념

3장의 카운터 발행자와 구독자, 4장의 단어 세기 서비스를 C++로 옮기고, Python 노드와 섞어 통신시켜 봅니다 (원서 PDF p.428~434).

- **rclcpp**: ROS 2의 C++ 클라이언트 라이브러리입니다. Python의 `rclpy` 에 해당합니다. 둘 다 아래쪽의 공통 C 라이브러리 `rcl` 위에 얹혀 있어서 개념과 이름이 거의 같습니다.
- **ament_cmake**: C++ 패키지의 빌드 방식입니다. Python 패키지의 `ament_python`(`setup.py`)에 해당하며, 원서의 catkin을 대신합니다.
- **CMakeLists.txt**: CMake라는 빌드 도구에게 주는 설명서입니다. 실행 파일 이름, 소스 파일, 의존 라이브러리, 설치 위치를 적습니다.
- **package.xml**: 패키지의 이름과 의존성을 선언하는 파일입니다. colcon은 이 파일을 보고 빌드 순서를 정하고, rosdep은 설치할 시스템 패키지를 정합니다.

원서가 말하듯 언제 C++를 쓸지는 "그 편이 일이 쉬워질 때"입니다 (원서 PDF p.426). 하드웨어 SDK가 C/C++로만 제공될 때, 이미 C++로 된 패키지를 고칠 때, 계산이 정말 무거울 때가 대표적입니다. 로보틱스 현장에서는 드라이버와 제어 루프에 C++가, 실험과 상위 로직에 Python이 많이 쓰이므로 두 언어 노드를 섞는 일이 흔합니다.

비유: 메시지 정의는 공용어 사전이고, rclpy와 rclcpp는 같은 사전을 쓰는 두 통역사입니다. 누가 통역했든 받는 쪽은 같은 문장을 받습니다.

## 2. 원서(ROS 1)와 달라지는 점

| 원서 (ROS 1) | ROS 2 Jazzy | 이유와 주의점 |
|---|---|---|
| `roscpp`, `#include <ros/ros.h>` | `rclcpp`, `#include "rclcpp/rclcpp.hpp"` | |
| `ros::init(argc, argv, "이름")` 후 `ros::NodeHandle` 생성 | `rclcpp::init(argc, argv)` 후 `rclcpp::Node` 를 상속한 클래스 생성 | 노드 이름은 init이 아니라 노드 생성자에 줍니다. 한 프로세스에 노드 여러 개를 둘 수 있게 바뀐 결과입니다. |
| `#include <std_msgs/Int32.h>`, `std_msgs::Int32` | `#include "std_msgs/msg/int32.hpp"`, `std_msgs::msg::Int32` | 헤더 파일 이름은 소문자와 밑줄(snake_case)로 바뀌고, 네임스페이스에 `msg`, `srv`, `action` 이 들어갑니다. |
| `node.advertise<T>("counter", 10)` | `create_publisher<T>("counter", 10)` | 10은 ROS 1의 버퍼 크기 대신 QoS의 큐 깊이(history depth)입니다. |
| `ros::Rate rate(1); while (ros::ok()) { ...; rate.sleep(); }` | `create_wall_timer(500ms, 콜백)` 후 `rclcpp::spin` | Python 쪽(3장)과 마찬가지로 루프 대신 타이머 콜백을 씁니다. |
| 콜백 인자 `const std_msgs::Int32::ConstPtr & msg`, `msg->data` | `const std_msgs::msg::Int32 & msg`, `msg.data` | 참조로 받으면 `.` 으로 접근합니다. 공유 포인터(`std_msgs::msg::Int32::SharedPtr`)로 받는 형태도 허용되며, 그때는 `->` 를 씁니다. |
| `std::cout` 로 출력 | `RCLCPP_INFO(get_logger(), "%d", msg.data)` | 21장의 로그 체계(화면, 파일, `/rosout`)를 타려면 로깅 매크로를 씁니다. |
| 서비스 콜백이 `bool` 을 반환해 성공과 실패를 알림 | 콜백 반환형 `void`, 응답 객체를 채우기만 함 | 실패를 알리려면 `.srv` 에 성공 여부 필드를 따로 둡니다. |
| `node.serviceClient<T>()` 와 동기 `client.call(srv)` | `create_client<T>()` 와 `async_send_request()` | ROS 2 클라이언트는 비동기가 기본입니다(4장의 Python 클라이언트와 같습니다). |
| `<build_depend>roscpp</build_depend>` + `<run_depend>roscpp</run_depend>` | `<depend>rclcpp</depend>` | 패키지 형식 3에서 `depend` 하나가 빌드, 내보내기, 실행 의존성을 모두 뜻합니다. |
| `find_package(catkin REQUIRED roscpp)`, `target_link_libraries(x ${catkin_LIBRARIES})` | `find_package(rclcpp REQUIRED)` 등을 패키지마다, `target_link_libraries(x rclcpp::rclcpp ${std_msgs_TARGETS})` | 의존성마다 무엇과 링크할지 직접 적습니다. |
| 빌드 결과가 `devel/lib/<패키지>/` 에 바로 생김 | `install(TARGETS ... DESTINATION lib/${PROJECT_NAME})` 를 적어야 `ros2 run` 이 찾음 | 이 줄을 빠뜨리면 빌드는 성공하지만 실행 파일을 찾지 못합니다(4절). |
| `catkin_make` | `colcon build --symlink-install --packages-select basics_cpp` | C++에서 `--symlink-install` 은 설치 폴더의 실행 파일을 빌드 폴더 결과물에 대한 링크로 만들 뿐입니다. 소스를 고치면 다시 빌드해야 합니다. |

## 3. 실습

### 실습 23-1. C++ 패키지 만들기

**준비**: 터미널 하나. 4장에서 만든 `basics_interfaces` 가 빌드되어 있어야 합니다.

**직접 입력**:

```bash
cd ~/rosbook_ws/src
ros2 pkg create --build-type ament_cmake --license Apache-2.0 basics_cpp --dependencies rclcpp std_msgs basics_interfaces
ls ~/rosbook_ws/src/basics_cpp
```

생성된 `~/rosbook_ws/src/basics_cpp/package.xml` 을 열어 의존성 부분이 다음과 같은지 확인합니다.

```xml
  <buildtool_depend>ament_cmake</buildtool_depend>

  <depend>rclcpp</depend>
  <depend>std_msgs</depend>
  <depend>basics_interfaces</depend>

  <test_depend>ament_lint_auto</test_depend>
  <test_depend>ament_lint_common</test_depend>

  <export>
    <build_type>ament_cmake</build_type>
  </export>
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `--build-type ament_cmake` | C++ 패키지 골격(`CMakeLists.txt`, `src/`, `include/basics_cpp/`)을 만듭니다. |
| `--dependencies rclcpp std_msgs basics_interfaces` | `package.xml` 에 `depend` 를, `CMakeLists.txt` 에 `find_package` 를 미리 넣어 줍니다. |
| `<buildtool_depend>ament_cmake</buildtool_depend>` | 이 패키지를 빌드하는 도구 자체에 대한 의존성입니다. |
| `<depend>rclcpp</depend>` | 빌드할 때도, 실행할 때도 rclcpp가 필요하다는 뜻입니다. 원서의 build_depend와 run_depend 두 줄을 합친 것입니다 (원서 PDF p.427). |
| `<depend>basics_interfaces</depend>` | 같은 워크스페이스의 인터페이스 패키지입니다. colcon은 이 줄을 보고 `basics_interfaces` 를 먼저 빌드합니다. |
| `<test_depend>ament_lint_*</test_depend>` | `colcon test` 때 코드 스타일 검사기를 씁니다(20장). |
| `<build_type>ament_cmake</build_type>` | colcon에게 이 패키지를 CMake로 빌드하라고 알립니다. |

**관찰**: `ls` 결과에 `CMakeLists.txt`, `include`, `package.xml`, `src` 가 있습니다. Python 패키지(3장)에 있던 `setup.py`, `setup.cfg`, `resource/` 는 없습니다.

**생각해 볼 질문**: `basics_interfaces` 를 `package.xml` 에는 적었는데 `CMakeLists.txt` 의 `find_package` 에서 빠뜨리면 어느 단계에서 실패할까요?

### 실습 23-2. 카운터 발행자와 구독자

**준비**: 실습 23-1의 패키지

**직접 입력**: 파일 `~/rosbook_ws/src/basics_cpp/src/topic_publisher.cpp`:

```cpp
#include <chrono>
#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/int32.hpp"

using namespace std::chrono_literals;

class TopicPublisher : public rclcpp::Node
{
public:
  TopicPublisher()
  : Node("topic_publisher"), count_(0)
  {
    pub_ = create_publisher<std_msgs::msg::Int32>("counter", 10);
    timer_ = create_wall_timer(500ms, [this]() {on_timer();});
  }

private:
  void on_timer()
  {
    std_msgs::msg::Int32 msg;
    msg.data = count_;
    pub_->publish(msg);
    ++count_;
  }

  rclcpp::Publisher<std_msgs::msg::Int32>::SharedPtr pub_;
  rclcpp::TimerBase::SharedPtr timer_;
  int32_t count_;
};

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<TopicPublisher>());
  rclcpp::shutdown();
  return 0;
}
```

파일 `~/rosbook_ws/src/basics_cpp/src/topic_subscriber.cpp`:

```cpp
#include <memory>

#include "rclcpp/rclcpp.hpp"
#include "std_msgs/msg/int32.hpp"

class TopicSubscriber : public rclcpp::Node
{
public:
  TopicSubscriber()
  : Node("topic_subscriber")
  {
    sub_ = create_subscription<std_msgs::msg::Int32>(
      "counter", 10,
      [this](const std_msgs::msg::Int32 & msg) {callback(msg);});
  }

private:
  void callback(const std_msgs::msg::Int32 & msg)
  {
    RCLCPP_INFO(get_logger(), "%d", msg.data);
  }

  rclcpp::Subscription<std_msgs::msg::Int32>::SharedPtr sub_;
};

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<TopicSubscriber>());
  rclcpp::shutdown();
  return 0;
}
```

**줄 단위 해설** (3장 Python 코드와 나란히):

| C++ | Python (3장) | 설명 |
|---|---|---|
| `#include "rclcpp/rclcpp.hpp"` | `import rclpy`, `from rclpy.node import Node` | 클라이언트 라이브러리를 가져옵니다. |
| `#include "std_msgs/msg/int32.hpp"` | `from std_msgs.msg import Int32` | 같은 `Int32.msg` 에서 생성된 코드입니다. C++ 헤더 이름은 소문자 `int32.hpp` 입니다. |
| `using namespace std::chrono_literals;` | 해당 없음 | `500ms` 처럼 단위가 붙은 시간 표기를 쓰게 합니다. |
| `class TopicPublisher : public rclcpp::Node` | `class TopicPublisher(Node):` | 노드를 상속해 자기 노드를 만듭니다. 원서의 ROS 1 코드에는 클래스가 없었지만, ROS 2에서는 이 형태가 표준입니다. |
| `: Node("topic_publisher"), count_(0)` | `super().__init__('topic_publisher')`, `self.count = 0` | 부모 생성자에 노드 이름을 주고, 멤버 변수를 초기화합니다. |
| `create_publisher<std_msgs::msg::Int32>("counter", 10)` | `self.create_publisher(Int32, 'counter', 10)` | C++은 메시지 타입을 꺾쇠 `< >` 안의 템플릿 인자로 줍니다. |
| `create_wall_timer(500ms, [this]() {on_timer();})` | `self.create_timer(0.5, self.timer_callback)` | `[this]() {...}` 는 람다(이름 없는 함수)입니다. `this` 를 붙잡아 두어야 멤버 함수를 부를 수 있습니다. `wall_timer` 는 `use_sim_time` 과 상관없이 컴퓨터 시계로 도는 타이머입니다. |
| `std_msgs::msg::Int32 msg;` | `msg = Int32()` | 메시지 객체를 만듭니다. C++은 스택에 바로 만듭니다. |
| `pub_->publish(msg);` | `self.pub.publish(msg)` | `pub_` 는 공유 포인터라 `->` 로 호출합니다. |
| `rclcpp::Publisher<...>::SharedPtr pub_;` | 해당 없음 | C++은 멤버 변수의 타입을 클래스 안에 선언해야 합니다. 이름 끝의 `_` 는 멤버 변수 표시 관례입니다. |
| `rclcpp::TimerBase::SharedPtr timer_;` | `self.timer = ...` | 타이머 객체를 멤버로 들고 있어야 합니다. 지역 변수로만 두면 생성자가 끝날 때 사라져 타이머가 돌지 않습니다. |
| `create_subscription<...>("counter", 10, 람다)` | `self.create_subscription(Int32, 'counter', self.callback, 10)` | 인자 순서가 다릅니다. C++은 큐 깊이가 콜백보다 앞에 옵니다. |
| `const std_msgs::msg::Int32 & msg` | `msg` | 메시지를 복사하지 않고 읽기 전용 참조로 받습니다. |
| `RCLCPP_INFO(get_logger(), "%d", msg.data);` | `self.get_logger().info(f'{msg.data}')` | C++은 `printf` 형식 문자열을 쓰는 매크로입니다. `%d` 는 정수 자리입니다. |
| `rclcpp::init(argc, argv);` | `rclpy.init(args=args)` | 명령줄의 `--ros-args` 를 여기서 읽습니다. |
| `rclcpp::spin(std::make_shared<TopicPublisher>());` | `node = TopicPublisher()`, `rclpy.spin(node)` | 노드를 공유 포인터로 만들어 바로 spin에 넘깁니다. |
| `rclcpp::shutdown(); return 0;` | `finally: node.destroy_node(); rclpy.try_shutdown()` | rclcpp는 Ctrl+C를 자체 시그널 처리기로 받아 spin을 끝내므로 `try/except` 가 필요 없습니다. 노드는 공유 포인터가 사라질 때 정리됩니다. |

**관찰**: 아직 빌드하지 않았습니다. 실습 23-3에서 빌드합니다.

**생각해 볼 질문**: 원서의 C++ 발행자는 `while` 루프와 `rate.sleep()` 으로 주기를 맞춥니다 (원서 PDF p.430). 이 노드에 구독자를 하나 더 붙이려면 루프 방식과 타이머 방식 중 어느 쪽이 쉬울까요?

### 실습 23-3. CMakeLists.txt 작성과 빌드

**준비**: 실습 23-2의 두 소스 파일

**직접 입력**: `~/rosbook_ws/src/basics_cpp/CMakeLists.txt` 의 `find_package(...)` 줄들 아래, `if(BUILD_TESTING)` 위에 다음을 넣습니다. 실습 23-4의 서비스 서버 줄도 미리 넣어 둡니다(23-4에서 소스를 만든 뒤 빌드합니다). 지금 바로 빌드해 보려면 `service_server` 관련 세 줄을 잠시 빼 둡니다.

```cmake
add_executable(topic_publisher src/topic_publisher.cpp)
target_link_libraries(topic_publisher rclcpp::rclcpp ${std_msgs_TARGETS})

add_executable(topic_subscriber src/topic_subscriber.cpp)
target_link_libraries(topic_subscriber rclcpp::rclcpp ${std_msgs_TARGETS})

add_executable(service_server src/service_server.cpp)
target_link_libraries(service_server rclcpp::rclcpp ${basics_interfaces_TARGETS})

install(TARGETS
  topic_publisher
  topic_subscriber
  service_server
  DESTINATION lib/${PROJECT_NAME}
)
```

파일 전체는 다음과 같은 모양이 됩니다. 위쪽과 아래쪽은 `ros2 pkg create` 가 만든 그대로입니다.

```cmake
cmake_minimum_required(VERSION 3.8)
project(basics_cpp)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# find dependencies
find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(std_msgs REQUIRED)
find_package(basics_interfaces REQUIRED)

# (위의 add_executable ~ install 부분)

if(BUILD_TESTING)
  # (생성된 그대로)
endif()

ament_package()
```

빌드하고 확인합니다.

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics_cpp
source ~/rosbook_ws/install/setup.bash
ros2 pkg executables basics_cpp
ls -l ~/rosbook_ws/install/basics_cpp/lib/basics_cpp/
ldd ~/rosbook_ws/install/basics_cpp/lib/basics_cpp/topic_publisher | grep -E 'rclcpp|std_msgs'
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `cmake_minimum_required(VERSION 3.8)` | 필요한 CMake 최소 버전입니다. |
| `project(basics_cpp)` | 프로젝트 이름입니다. `package.xml` 의 `<name>` 과 같아야 합니다. 아래의 `${PROJECT_NAME}` 이 이 값이 됩니다. |
| `add_compile_options(-Wall -Wextra -Wpedantic)` | 컴파일러 경고를 넉넉히 켭니다. 경고는 무시하지 말고 읽는 습관을 들입니다. |
| `find_package(rclcpp REQUIRED)` | 설치된 rclcpp를 찾아 `rclcpp::rclcpp` 라는 링크 대상을 만듭니다. 없으면 여기서 멈춥니다. |
| `find_package(std_msgs REQUIRED)` | `${std_msgs_TARGETS}` 변수를 만듭니다. 메시지 패키지는 이 변수로 링크합니다. |
| `add_executable(topic_publisher src/topic_publisher.cpp)` | 소스 파일 하나로 실행 파일 `topic_publisher` 를 만든다고 알립니다. 실행 파일 이름이 곧 `ros2 run` 에 쓰는 이름입니다. |
| `target_link_libraries(topic_publisher rclcpp::rclcpp ${std_msgs_TARGETS})` | 그 실행 파일이 쓸 라이브러리를 연결합니다. 헤더 검색 경로도 이 줄을 통해 함께 들어옵니다(4절의 실험). |
| `install(TARGETS ... DESTINATION lib/${PROJECT_NAME})` | 빌드 결과를 `install/basics_cpp/lib/basics_cpp/` 에 놓습니다. `ros2 run` 은 이 위치만 찾습니다. Python의 `setup.py` 에서 `console_scripts` 가 하던 역할입니다. |
| `if(BUILD_TESTING) ... endif()` | `colcon test` 때만 쓰이는 검사기 설정입니다. 저작권 표시와 cpplint 검사는 생성기가 꺼 둔 상태입니다. |
| `ament_package()` | 다른 패키지가 이 패키지를 찾을 수 있게 정보를 내보냅니다. 항상 파일 맨 끝에 둡니다. |
| `ros2 pkg executables basics_cpp` | `ros2 run` 으로 실행할 수 있는 이름 목록입니다. |
| `ldd` | 실행 파일이 실행될 때 불러오는 공유 라이브러리를 보여 줍니다. |

**관찰**:
- `ros2 pkg executables basics_cpp` 가 `basics_cpp service_server`, `basics_cpp topic_publisher`, `basics_cpp topic_subscriber` 를 출력합니다(서비스 서버를 뺐다면 두 줄).
- `ls -l` 결과의 실행 파일은 `-> .../build/basics_cpp/topic_publisher` 처럼 빌드 폴더를 가리키는 심볼릭 링크입니다. `--symlink-install` 의 효과는 여기까지입니다.
- `ldd` 결과에 `librclcpp.so => /opt/ros/jazzy/lib/librclcpp.so` 와 `libstd_msgs__rosidl_typesupport_cpp.so` 가 보입니다.
- 첫 빌드는 10초 남짓 걸립니다. Python 패키지보다 확실히 느립니다(원서 PDF p.426~427의 지적과 같습니다).

**생각해 볼 질문**: `--symlink-install` 로 빌드했는데 `.cpp` 를 고친 뒤 다시 빌드하지 않고 실행하면 어떻게 될까요? 4절의 실험으로 확인합니다.

### 실습 23-4. 단어 세기 서비스 서버

**준비**: 4장의 `basics_interfaces/srv/WordCount.srv`(요청 `string words`, 응답 `uint32 count`)

**직접 입력**: 파일 `~/rosbook_ws/src/basics_cpp/src/service_server.cpp`:

```cpp
#include <cstdint>
#include <memory>
#include <sstream>
#include <string>

#include "basics_interfaces/srv/word_count.hpp"
#include "rclcpp/rclcpp.hpp"

using WordCount = basics_interfaces::srv::WordCount;

class ServiceServer : public rclcpp::Node
{
public:
  ServiceServer()
  : Node("service_server")
  {
    srv_ = create_service<WordCount>(
      "word_count",
      [this](const std::shared_ptr<WordCount::Request> request,
      std::shared_ptr<WordCount::Response> response) {count_words(request, response);});
  }

private:
  void count_words(
    const std::shared_ptr<WordCount::Request> request,
    std::shared_ptr<WordCount::Response> response)
  {
    std::istringstream stream(request->words);
    std::string word;
    uint32_t count = 0;
    while (stream >> word) {
      ++count;
    }
    response->count = count;
    RCLCPP_INFO(get_logger(), "\"%s\" -> %u", request->words.c_str(), count);
  }

  rclcpp::Service<WordCount>::SharedPtr srv_;
};

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  rclcpp::spin(std::make_shared<ServiceServer>());
  rclcpp::shutdown();
  return 0;
}
```

실습 23-3의 `CMakeLists.txt` 에 `service_server` 줄이 모두 들어 있는지 확인하고 빌드합니다.

```bash
cd ~/rosbook_ws && colcon build --symlink-install --packages-select basics_cpp
source ~/rosbook_ws/install/setup.bash
ros2 run basics_cpp service_server
```

터미널 2:

```bash
ros2 service list -t
ros2 service call /word_count basics_interfaces/srv/WordCount "{words: 'one two three four'}"
ros2 service call /word_count basics_interfaces/srv/WordCount "{words: ''}"
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `#include "basics_interfaces/srv/word_count.hpp"` | `WordCount.srv` 에서 생성된 C++ 헤더입니다. 파일 이름은 `word_count` 로 바뀝니다. |
| `using WordCount = ...;` | 긴 타입 이름에 짧은 별명을 붙입니다. |
| `create_service<WordCount>("word_count", 람다)` | 서비스 서버를 만듭니다. Python의 `self.create_service(WordCount, 'word_count', self.count_words)` 에 해당합니다. |
| `std::shared_ptr<WordCount::Request> request` | 요청 객체입니다. 포인터라서 `request->words` 로 읽습니다. |
| `std::shared_ptr<WordCount::Response> response` | 비어 있는 응답 객체입니다. 콜백이 이것을 채우면 rclcpp가 돌려보냅니다. 반환값은 없습니다. |
| `std::istringstream stream(request->words);` | 문자열을 단어 단위로 읽는 스트림을 만듭니다. |
| `while (stream >> word) { ++count; }` | 공백(여러 칸, 탭 포함)으로 나뉜 단어를 하나씩 읽으며 셉니다. Python의 `len(words.split())` 과 같은 결과입니다. |
| `RCLCPP_INFO(..., "\"%s\" -> %u", request->words.c_str(), count)` | C++ 문자열은 `.c_str()` 로 바꿔야 `%s` 에 넣을 수 있습니다. `%u` 는 부호 없는 정수 자리입니다. |
| `target_link_libraries(service_server rclcpp::rclcpp ${basics_interfaces_TARGETS})` | 직접 만든 인터페이스 패키지도 표준 메시지와 똑같은 방식으로 링크합니다. |

**관찰**:
- `ros2 service list -t` 에 `/word_count [basics_interfaces/srv/WordCount]` 가 있습니다.
- 첫 호출의 응답은 `basics_interfaces.srv.WordCount_Response(count=4)`, 빈 문자열은 `count=0` 입니다.
- 서버 터미널에 `"one two three four" -> 4`, `"" -> 0` 이 찍힙니다.
- 응답을 출력한 `ros2 service call` 은 Python으로 된 도구입니다. Python 클라이언트가 C++ 서버를 부른 셈입니다.

**생각해 볼 질문**: 원서의 서버는 공백 문자의 개수에 1을 더해 단어 수를 셉니다 (원서 PDF p.433). `"one  two"`(공백 두 칸)나 `" one"` 을 보내면 원서 방식과 이 장의 방식은 각각 몇이라고 답할까요?

### 실습 23-5. 언어를 섞어 통신하기

**준비**: 터미널 세 개. 3장의 `basics` 와 이 장의 `basics_cpp` 가 모두 빌드되어 있어야 합니다.

**직접 입력**:

터미널 1:

```bash
ros2 run basics_cpp topic_publisher
```

터미널 2:

```bash
ros2 run basics topic_subscriber
```

터미널 3:

```bash
ros2 node list
ros2 topic info -v /counter
```

터미널 1과 2를 Ctrl+C로 멈추고, 이번에는 언어를 바꿉니다.

터미널 1:

```bash
ros2 run basics topic_publisher
```

터미널 2:

```bash
ros2 run basics_cpp topic_subscriber
```

**줄 단위 해설**:

| 줄 | 설명 |
|---|---|
| `ros2 run basics_cpp topic_publisher` | C++ 발행자입니다. 노드 이름이 Python 쪽과 같은 `topic_publisher` 이므로 둘을 동시에 띄우지는 않습니다. |
| `ros2 run basics topic_subscriber` | 3장의 Python 구독자입니다. |
| `ros2 topic info -v /counter` | 발행자와 구독자의 노드 이름, 타입, QoS를 봅니다. 언어 정보는 어디에도 없습니다. |

**관찰**:
- C++ 발행자와 Python 구독자: 구독자 터미널에 `[topic_subscriber]: 0`, `1`, `2` 가 0.5초 간격으로 찍힙니다.
- Python 발행자와 C++ 구독자: 구독자 터미널에 같은 형식으로 `0`, `1`, `2` 가 찍힙니다. 로그 형식도 같습니다. 둘 다 같은 로깅 라이브러리(`rcutils`)를 쓰기 때문입니다.
- C++ 노드를 Ctrl+C로 멈추면 `[INFO] [...] [rclcpp]: signal_handler(SIGINT/SIGTERM)` 한 줄이 찍히고 깔끔하게 끝납니다. Python 노드처럼 트레이스백이 나오지 않습니다.

**생각해 볼 질문**: 실제 로봇에서 라이다 드라이버는 C++, 장애물 판단은 Python으로 썼다고 합시다. 판단 노드가 느려서 메시지를 놓친다면 어느 노드를 C++로 다시 쓸지 결정하기 전에 무엇부터 재 봐야 할까요?

## 4. 일부러 망가뜨려 보기

| 바꿀 것 | 예상 증상 | 원인을 확인하는 명령 |
|---|---|---|
| `CMakeLists.txt` 에서 `install(TARGETS ...)` 블록을 지우고 빌드 | 빌드는 성공합니다. `ros2 run basics_cpp topic_publisher` 가 `No executable found` 를 출력합니다. | `ros2 pkg executables basics_cpp`, `ls ~/rosbook_ws/install/basics_cpp/lib/basics_cpp` |
| `target_link_libraries(topic_publisher rclcpp::rclcpp)` 로 `${std_msgs_TARGETS}` 를 뺌 | 컴파일 단계에서 `fatal error: std_msgs/msg/int32.hpp: No such file or directory` 로 실패합니다. 링크 줄이 헤더 검색 경로까지 책임진다는 뜻입니다. | 오류 메시지의 첫 줄과 파일 이름 |
| 구독자 콜백 인자를 `const std_msgs::msg::String & msg` 로 바꿈(헤더는 그대로) | `error: 'String' in namespace 'std_msgs::msg' does not name a type` 으로 실패합니다. 헤더를 넣고 타입만 다르게 하면 템플릿 오류가 길게 이어지므로 첫 `error:` 줄부터 읽습니다. | `colcon build` 출력에서 첫 `error:` 줄 |
| `--symlink-install` 로 빌드한 뒤 `500ms` 를 `100ms` 로 고치고 다시 빌드하지 않음 | 여전히 2 Hz로 발행합니다. 다시 빌드하면 10 Hz가 됩니다. | `ros2 topic hz /counter` |
| C++ 구독자가 떠 있는 `/counter` 에 `ros2 topic pub /counter std_msgs/msg/Float64 "{data: 1.5}"` | 구독자는 아무것도 받지 못하고 경고도 없습니다(21장의 타입 불일치와 같습니다). | `ros2 topic list -t` |
| `timer_` 를 멤버가 아닌 생성자의 지역 변수(`auto timer = create_wall_timer(...)`)로 만듦 | 노드는 떠 있지만 아무것도 발행하지 않을 것으로 예상합니다. 타이머 객체가 생성자 끝에서 사라지기 때문입니다. | `ros2 topic hz /counter`, `ros2 node info /topic_publisher` |
| `package.xml` 의 `<depend>basics_interfaces</depend>` 를 지우고 워크스페이스 전체를 처음부터 빌드 | colcon이 빌드 순서를 모르게 되어, `basics_interfaces` 보다 먼저 빌드되면 `find_package(basics_interfaces)` 에서 실패할 수 있습니다. | `colcon graph` |

## 5. 확인 질문

<details><summary>Q1. 실습 23-1의 질문: `find_package(basics_interfaces)` 를 빠뜨리면?</summary>

CMake 설정 단계는 통과할 가능성이 큽니다. 대신 `${basics_interfaces_TARGETS}` 가 빈 값이 되어 헤더 경로가 잡히지 않으므로, 컴파일 단계에서 `basics_interfaces/srv/word_count.hpp` 를 찾지 못하는 컴파일 오류가 납니다. 4절의 `${std_msgs_TARGETS}` 를 뺀 실험과 같은 모양의 오류입니다. `package.xml` 은 빌드 순서와 설치 의존성을 정할 뿐, CMake에게 무엇을 찾을지 알려 주지 않습니다.

</details>

<details><summary>Q2. 실습 23-2의 질문: 구독자를 더 붙이려면 루프와 타이머 중 어느 쪽이 쉬운가요?</summary>

타이머 쪽입니다. 루프 방식은 `rate.sleep()` 으로 잠든 동안 다른 콜백을 처리할 기회가 없어서, 구독 콜백을 돌리려면 루프 안에서 따로 처리 함수를 불러야 합니다. 타이머 방식은 `rclcpp::spin` 이 타이머와 구독 콜백을 모두 같은 실행기에서 돌려 주므로 `create_subscription` 한 줄만 더하면 됩니다.

</details>

<details><summary>Q3. 실습 23-3의 질문: 다시 빌드하지 않고 실행하면?</summary>

예전 동작 그대로입니다. `--symlink-install` 은 `install/` 의 실행 파일을 `build/` 의 결과물에 대한 링크로 만들 뿐이고, `.cpp` 를 기계어로 바꾸는 일은 빌드할 때만 일어납니다. Python 패키지에서는 링크가 소스 파일 자체를 가리키므로 고친 내용이 바로 반영되지만, C++에서는 반드시 다시 빌드해야 합니다. 4절의 실험에서 다시 빌드하기 전에는 2 Hz, 다시 빌드한 뒤에는 10 Hz였습니다.

</details>

<details><summary>Q4. 실습 23-4의 질문: 공백이 이상한 문자열의 단어 수는?</summary>

`"one  two"` 는 원서 방식으로 공백 2개 + 1 = 3, 이 장의 방식으로 2입니다. `" one"` 은 원서 방식으로 2, 이 장의 방식으로 1입니다. 원서 방식은 공백 개수를 세므로 연속 공백이나 앞뒤 공백에서 틀립니다. 이 장의 방식은 스트림이 공백을 건너뛰며 단어만 읽으므로 4장의 Python `split()` 과 같은 답을 냅니다.

</details>

<details><summary>Q5. 실습 23-5의 질문: C++로 다시 쓰기 전에 무엇을 재야 하나요?</summary>

느린 곳이 정말 판단 노드의 계산인지부터 잽니다. `ros2 topic hz` 로 입력과 출력 주기를 비교하고, 콜백 하나에 걸리는 시간을 로그로 남기고, QoS 큐 깊이가 너무 작아서 버리는 것은 아닌지 확인합니다. 원서가 말하듯 numpy나 scipy 같은 라이브러리는 이미 내부가 C로 되어 있어서, 다시 쓰는 비용에 비해 얻는 것이 적을 수 있습니다 (원서 PDF p.426).

</details>

## 6. 원서 대조 메모

- 원서의 C++ 발행자는 1 Hz로 발행하고 노드 이름이 `count_publisher` 입니다 (원서 PDF p.430). 3장의 Python 발행자는 2 Hz이므로 같은 노드의 번역으로 보기에는 주기가 다릅니다. 이 장은 3장에 맞춰 0.5초 주기, 노드 이름 `topic_publisher` 로 옮겼습니다.
- 원서의 C++ 구독자는 `main` 이 값을 반환하지 않습니다 (원서 PDF p.431). C++ 표준에서 `main` 은 반환문이 없어도 0을 반환한 것으로 처리되므로 오류는 아니지만, 바로 앞의 예제와 일관되지 않습니다. 또 로그 대신 `std::cout` 으로 출력해서 `/rosout` 에 남지 않습니다.
- 원서의 서비스 서버 예제(원서 PDF p.432~433)는 그대로는 컴파일되지 않습니다.
  - 변수 `l` 과 `count` 를 선언하지 않았습니다.
  - 지역 변수 `count` 가 함수 이름 `count` 와 겹칩니다.
  - `strlen` 은 C 문자열용인데 `std::string` 에 썼습니다.
  - `ros::init(int argc, char **argv, ...)` 처럼 호출하는 자리에 타입을 적었습니다.
  - 단어 수를 공백 수로 세서 연속 공백에서 틀립니다(Q4).
  - 서비스 이름이 4장의 `word_count` 가 아니라 `count` 입니다.
- 원서의 서비스 클라이언트 예제(원서 PDF p.433~434)도 `ros::init(argc, char **argv, ...)` 로 타입이 섞여 있어 컴파일되지 않습니다. 이 장은 클라이언트를 C++로 쓰지 않고 `ros2 service call` 로 대신했습니다.
- 원서의 `catkin_make`, `devel/lib/<패키지>/`, `${catkin_LIBRARIES}` 는 각각 `colcon build`, `install/<패키지>/lib/<패키지>/`, 의존성별 링크 대상으로 바뀝니다.
- 원서는 액션의 C++ 예제를 다루지 않습니다. rclcpp의 액션은 별도 패키지 `rclcpp_action` 을 씁니다(이 장에서는 다루지 않음).

## 7. 이 문서의 검증 상태

- 확인함 (2026-10-27, 검증용 별도 워크스페이스, `ROS_DOMAIN_ID` 분리, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp`):
  - `ros2 pkg create --build-type ament_cmake --license Apache-2.0 basics_cpp --dependencies rclcpp std_msgs` 로 만든 골격(이후 `basics_interfaces` 의존성은 손으로 추가해 검증).
  - 이 문서의 세 소스 파일, `CMakeLists.txt`, `package.xml` 그대로 `colcon build --symlink-install` 성공. `ros2 pkg executables basics_cpp` 세 줄, 설치 폴더의 심볼릭 링크, `ldd` 의 `librclcpp.so`.
  - C++ 발행자와 Python 구독자, Python 발행자와 C++ 구독자 양방향 수신(0.5초 간격 `0`, `1`, `2` ...). C++ 노드 종료 시 `signal_handler(SIGINT/SIGTERM)` 로그.
  - `/word_count [basics_interfaces/srv/WordCount]`, `count=4`, 빈 문자열 `count=0`, 서버 로그 `"one two three four" -> 4`.
  - `colcon test --packages-select basics_cpp`: lint_cmake, uncrustify, xmllint 통과, cppcheck는 건너뜀(skipped).
  - 4절의 다섯 가지: `install` 삭제 시 `No executable found`, `${std_msgs_TARGETS}` 삭제 시 `int32.hpp: No such file or directory`, `String` 으로 바꾸면 `does not name a type`, 다시 빌드 전 2 Hz와 다시 빌드 후 10 Hz, Float64 발행 시 C++ 구독자 무수신. 수정 후 다시 빌드 약 5초, 첫 빌드 약 10초.
- 확인 못 함:
  - `--dependencies` 에 `basics_interfaces` 까지 한 번에 넣은 `ros2 pkg create` 명령(같은 형식이라 동작할 것으로 봅니다).
  - 4절의 `timer_` 를 지역 변수로 만든 경우와 `package.xml` 의존성을 지운 경우(예상만 적었습니다).
  - Q1의 `find_package` 누락 시 정확한 오류 위치, Q4의 연속 공백 입력에 대한 실제 응답(원서 방식은 컴파일되지 않아 실행 불가, 이 장 방식은 `std::istringstream` 의 동작에 근거).
  - 원서의 C++ 코드 자체는 ROS 1 환경이 없어 컴파일해 보지 않았습니다. 6절의 오류는 코드를 읽어 판단했습니다.
