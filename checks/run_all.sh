#!/bin/bash
# checks/ 의 검증 스크립트를 모두 차례로 실행하고, 끝에 실패한 스크립트를 모아 보여 줍니다.
cd "$(dirname "$0")" || exit 1
total=0
failed=()
for script in *.sh; do
  case "$script" in
    common.sh | run_all.sh) continue ;;
  esac
  total=$((total + 1))
  echo "===== $script"
  bash "$script" || failed+=("$script")
  echo
done
echo "===== 요약: 스크립트 ${total}개 중 실패 ${#failed[@]}개 ${failed[*]}"
[ "${#failed[@]}" -eq 0 ]
