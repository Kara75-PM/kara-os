#!/usr/bin/env bash
# 카라 OS 스킬 설치 (macOS / Linux)
#
#   bash install.sh                       물어보고 고릅니다
#   bash install.sh --all                 있는 것 전부
#   bash install.sh sns-writing           이것만
#   bash install.sh sns-writing source-to-lead
#   bash install.sh --local ...           지금 폴더의 .claude/skills 에만
#   bash install.sh --list                뭐가 있는지 보기만 (아무것도 안 함)
#
# 이 스크립트는 파일을 지우지 않습니다.
# 같은 이름이 이미 있으면, 허락을 받은 뒤 <이름>.old-날짜 로 옆에 치워둡니다.
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills"
PICK=(); ALL=""; LIST=""

for a in "$@"; do
  case "$a" in
    --local) DEST="$(pwd)/.claude/skills" ;;
    --all)   ALL=1 ;;
    --list)  LIST=1 ;;
    -*)      echo "모르는 옵션: $a"; echo "쓸 수 있는 것: --all  --local  --list  또는 스킬 이름"; exit 1 ;;
    *)       PICK+=("$a") ;;
  esac
done

AVAIL=()
for d in "$SRC"/skills/*/; do
  [ -f "$d/SKILL.md" ] && AVAIL+=("$(basename "$d")")
done
if [ ${#AVAIL[@]} -eq 0 ]; then
  echo "[중단] skills/ 안에 설치할 스킬이 없습니다."
  echo "       이 스크립트는 저장소를 받은 폴더 안에서 실행해야 합니다."
  exit 1
fi

show_list() {
  echo "이 저장소에 들어 있는 스킬:"
  local i=1 one
  for s in "${AVAIL[@]}"; do
    # 맥 기본 bash(3.2)의 ${x:0:n} 은 바이트로 잘라서 한글이 깨진다. 자르지 않는다.
    one=$(sed -n '5,9p' "$SRC/skills/$s/README.md" 2>/dev/null | grep -m1 '[가-힣]' \
          | sed 's/^[*> ]*//;s/\*\*//g' | cut -d'.' -f1)
    printf "  %d) %-16s %s\n" "$i" "$s" "$one"
    i=$((i+1))
  done
}

if [ -n "$LIST" ]; then show_list; exit 0; fi

if [ ${#PICK[@]} -eq 0 ] && [ -z "$ALL" ]; then
  show_list
  echo
  printf "무엇을 설치할까요? 번호를 띄어쓰기로 (전부 설치는 그냥 엔터): "
  ANS=""; read -r ANS || true
  if [ -z "$ANS" ]; then
    PICK=("${AVAIL[@]}")
  else
    for n in $ANS; do
      case "$n" in ''|*[!0-9]*) echo "[중단] '$n' 은 번호가 아닙니다."; exit 1 ;; esac
      idx=$((n-1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#AVAIL[@]} ]; then PICK+=("${AVAIL[$idx]}")
      else echo "[중단] $n 번은 없는 번호입니다."; exit 1; fi
    done
  fi
elif [ -n "$ALL" ]; then
  PICK=("${AVAIL[@]}")
else
  for s in "${PICK[@]}"; do
    if [ ! -f "$SRC/skills/$s/SKILL.md" ]; then
      echo "[중단] '$s' 는 이 저장소에 없습니다."; echo; show_list; exit 1
    fi
  done
fi

echo
echo "== 카라 OS 스킬 설치 =="
echo "   받는 곳: $DEST"
echo

HAD_SKILLS=1
[ -d "$DEST" ] || HAD_SKILLS=0
mkdir -p "$DEST"

for S in "${PICK[@]}"; do
  if [ -d "$DEST/$S" ]; then
    echo "[확인] $S 이(가) 이미 있습니다."
    echo "       덮어쓰면 기존 폴더를 $S.old-<날짜> 로 옆에 치워둡니다. 지우지 않습니다."
    printf "       진행할까요? (y/N) "
    ANS=n; read -r ANS || true
    case "$ANS" in
      y|Y) OLD="$S.old-$(date +%Y%m%d-%H%M%S)"
           mv "$DEST/$S" "$DEST/$OLD"
           echo "       옆으로 치워뒀습니다 → $OLD" ;;
      *)   echo "       건너뜁니다."; continue ;;
    esac
  fi
  cp -R "$SRC/skills/$S" "$DEST/"
  N=$(find "$DEST/$S" -name '*.md' | wc -l | tr -d ' ')
  echo "[OK] $S  문서 ${N}개"
done

echo
if [ "$HAD_SKILLS" = "0" ]; then
  echo "[중요] 클로드 코드를 한 번 껐다 켜 주세요."
  echo "       스킬 폴더가 방금 처음 생겼기 때문입니다. 고장이 아닙니다."
else
  echo "다시 켜지 않아도 바로 잡힙니다."
fi
echo
echo "설치한 곳:   $DEST"
echo "받아온 원본: $SRC"
echo "             (임시 폴더입니다. 컴퓨터를 끄면 사라지니 필요하면 옮겨두세요)"
echo
echo "이렇게 불러 보세요:"
echo "   스레드 글 써줘"
echo "   재료 폴더 만들어줘"
