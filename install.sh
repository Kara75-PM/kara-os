#!/usr/bin/env bash
# 카라 OS 스킬 설치 (macOS / Linux)
# 사용법:  bash install.sh          전역 설치 (~/.claude/skills)
#          bash install.sh .        지금 폴더에만 (./.claude/skills)
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
if [ "$1" = "." ]; then DEST="$(pwd)/.claude/skills"; else DEST="$HOME/.claude/skills"; fi

echo "== 카라 OS 스킬 설치 =="
echo "   받는 곳: $DEST"
echo

# 설치 전에 skills 폴더가 원래 있었는지 기억해 둔다 (재시작 안내에 씀)
HAD_SKILLS=1
[ -d "$DEST" ] || HAD_SKILLS=0
mkdir -p "$DEST"

for S in sns-writing source-to-lead; do
  if [ -d "$DEST/$S" ]; then
    printf "[확인] %s 이(가) 이미 있습니다. 덮어쓸까요? (y/N) " "$S"
    read -r ANS </dev/tty || ANS=n
    case "$ANS" in
      y|Y) echo "       덮어씁니다." ;;
      *)   echo "       건너뜁니다."; continue ;;
    esac
  fi
  cp -R "$SRC/skills/$S" "$DEST/"
  N=$(find "$DEST/$S" -type f | wc -l | tr -d ' ')
  echo "[OK] $S  파일 ${N}개"
done

echo
if [ "$HAD_SKILLS" = "0" ]; then
  echo "🔴 중요 — 클로드 코드를 한 번 껐다 켜 주세요."
  echo "   스킬 폴더가 방금 처음 생겼기 때문입니다. 고장이 아닙니다."
else
  echo "다시 켜지 않아도 바로 잡힙니다."
fi
echo
echo "이렇게 불러 보세요:"
echo "   스레드 글 써줘"
echo "   이 소재로 콘텐츠 만들어줘. 신청은 (주소)로 받을 거야"
