# 검증 스크립트

이 폴더의 스크립트는 가이드 본문에 적은 동작 가운데, 문서를 고치게 만든 동작과 오해하기 쉬운 동작을 다시 확인합니다. 각 장 7절의 "결함 수정" 기록이 근거로 가리키는 것이 이 스크립트들입니다.

실습을 대신하는 도구가 아닙니다. 실습은 본문대로 직접 입력하고, 결과가 문서와 다를 때 이 스크립트로 문서 쪽 설명이 지금 환경에서도 맞는지 확인합니다.

## 실행 방법

WSL의 Ubuntu 터미널에서 저장소 폴더로 이동한 뒤 실행합니다. ROS 2 Jazzy가 `/opt/ros/jazzy`에 설치되어 있어야 합니다.

```bash
bash checks/run_all.sh
```

스크립트 하나만 실행하려면 `bash checks/<스크립트 이름>.sh`를 입력합니다.

- 확인한 항목마다 `PASS:` 또는 `FAIL:`을, 판정 없이 기록만 하는 정보는 `INFO:`를 출력합니다. 마지막 줄은 `ALL PASS` 또는 실패 개수입니다.
- 작업 폴더는 `/tmp/rosbook_check.XXXXXX`로 새로 만들고 끝날 때 지웁니다. `~/rosbook_ws`는 건드리지 않습니다.
- 기본 도메인을 피해 스크립트마다 다른 `ROS_DOMAIN_ID`(56~67)를 쓰므로, 실행 중인 다른 노드와 섞이지 않습니다.
- daemon은 스크립트가 띄운 것만 끝날 때 끄며, 중간에 멈춘 경우에도 끕니다. 다른 곳에서 띄운 daemon은 쓰고 있을 수 있으므로 그대로 둡니다.
- RMW는 `RMW_IMPLEMENTATION`이 비어 있으면 Cyclone DDS를 씁니다. `type_mismatch_warning.sh`만 Cyclone DDS와 Fast DDS를 모두 씁니다.
- 패키지를 임시로 빌드하는 스크립트가 있어서, 모두 실행하면 몇 분 걸립니다.

## 스크립트 목록

| 스크립트 | 확인하는 내용 | 관련 문서 |
|---|---|---|
| `domain_no_daemon.sh` | daemon이 없는 도메인에서 `ros2 node list --no-daemon`은 바로 끝나는지, 붙이지 않으면 이 PC에서 멈추는지 | 1장 4절, 2장 실습 2-2 |
| `composition_demo.sh` | composition 데모 컴포넌트 두 개를 컨테이너 하나에 올렸을 때 보이는 노드, 프로세스, 출력 | 2장 실습 2-10 |
| `stale_launch_install.sh` | `setup.py`의 launch `data_files` 줄을 지우고 다시 빌드만 하면 전에 만든 링크로 launch가 그대로 되고, 그 패키지의 `build/`와 `install/`을 지운 뒤에야 실패하는지 | 2장 4절, 20장 4절 |
| `rclpy_unstored_refs.sh` | rclpy에서 `create_timer`와 `create_subscription`의 반환값을 저장하지 않아도 동작하는지 | 3장 2절, 실습 3-1, Q1 |
| `topic_pub_waits.sh` | `ros2 topic pub -t 3`이 구독자를 기다렸다가 발행해서 세 메시지가 모두 도착하는지 | 3장 실습 3-7 |
| `type_mismatch_warning.sh` | 타입이 다른 발행자와 구독자를 다른 프로세스에 만들 때와 한 프로세스에 만들 때, 경고나 오류가 나오는지를 Cyclone DDS와 Fast DDS에서 비교 | 3장 4절, 21장 실습 21-4, 23장 4절 |
| `service_returns_none.sh` | 서비스 콜백이 `None`을 돌려줄 때 서버와 클라이언트가 어떻게 되는지 | 4장 4절, Q2 |
| `action_simple_server.sh` | 단일 스레드 액션 서버가 goal 두 개를 차례로 처리하는지, 클라이언트가 꺼진 뒤에도 goal을 끝까지 실행하는지 | 5장 Q2, Q5 |
| `action_cancel_reject.sh` | 취소 콜백이 거절하거나 없을 때의 취소 응답(`return_code`, `goals_canceling`)과 최종 상태 | 5장 Q4 |
| `rclcpp_local_timer.sh` | rclcpp에서 생성자의 지역 변수에만 담은 타이머가 동작하는지 | 23장 4절, 3장 Q1 |
| `stale_cmake_install.sh` | `install(TARGETS ...)`을 지우고 다시 빌드만 하면 전에 만든 링크로 실행되고, 그 패키지의 `build/`와 `install/`을 지운 뒤에야 `No executable found`가 나오는지 | 23장 4절 |

## 새 스크립트를 더할 때

- 맨 앞에서 `common.sh`를 source 하고, 노드를 띄운다면 아직 쓰지 않은 `ROS_DOMAIN_ID`를 정합니다.
- 백그라운드 프로세스는 `run_bg`로 띄우고 `stop_bg`로 끕니다. daemon이 필요하면 `start_daemon`으로 띄웁니다. 판정은 `pass`, `fail`, 기록은 `info`로 출력하고, 마지막에 `finish`를 부릅니다.
- 이 README의 표와, 근거로 쓰는 장의 7절에 스크립트 이름을 적습니다(CONVENTIONS 9-4).
