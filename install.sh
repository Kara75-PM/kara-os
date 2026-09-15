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
# 무엇을 할지 먼저 보여주고 「y」를 받은 뒤에만 설치합니다. 그냥 엔터는 언제나 「안 한다」입니다.
# 같은 이름이 이미 있으면, 하나씩 따로 묻고 <이름>.old-날짜 로 옆에 치워둡니다.
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

# y 로 답했을 때만 「예」. 엔터·그 밖의 글자는 전부 「아니오」.
# 한글 자판 그대로 친 y(ㅛ)도 「예」로 받는다.
ask_yes() {
  local a=""
  read -r a || true
  case "$a" in
    y|Y|yes|Yes|YES|ㅛ) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -n "$LIST" ]; then show_list; exit 0; fi

if [ ${#PICK[@]} -eq 0 ] && [ -z "$ALL" ]; then
  show_list
  echo
  printf "무엇을 설치할까요? 번호를 띄어쓰기로 (전부 설치는 그냥 엔터 — 설치 전에 한 번 더 묻습니다): "
  ANS=""; read -r ANS || true
  if [ -z "$ANS" ]; then
    PICK=("${AVAIL[@]}")
  else
    for n in $ANS; do
      case "$n" in ''|*[!0-9]*) echo "[중단] '$n' 은 번호가 아닙니다. 아무것도 설치하지 않았습니다."; exit 1 ;; esac
      idx=$((n-1))
      if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#AVAIL[@]} ]; then PICK+=("${AVAIL[$idx]}")
      else echo "[중단] $n 번은 없는 번호입니다. 아무것도 설치하지 않았습니다."; exit 1; fi
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

# ── 설치 계획 — 아무것도 바꾸기 전에 보여주고 묻는다 ──────────────────
echo
echo "== 설치 계획 — 아직 아무것도 바꾸지 않았습니다 =="
echo "   받는 곳: $DEST"
echo
NEW_N=0; SAME_N=0; DIFF_N=0
for S in "${PICK[@]}"; do
  if [ ! -d "$DEST/$S" ]; then
    printf "   [새로 설치]   %s\n" "$S"; NEW_N=$((NEW_N+1))
  elif diff -rq "$SRC/skills/$S" "$DEST/$S" >/dev/null 2>&1; then
    printf "   [이미 같은 판] %s  — 건드리지 않습니다\n" "$S"; SAME_N=$((SAME_N+1))
  else
    printf "   [이미 있음]   %s  — 바꿀지 따로 한 번 더 묻습니다\n" "$S"; DIFF_N=$((DIFF_N+1))
  fi
done
echo

if [ $((NEW_N+DIFF_N)) -eq 0 ]; then
  echo "고른 스킬이 모두 이미 같은 판으로 설치돼 있습니다. 바꿀 것이 없어 끝냅니다."
  exit 0
fi

echo "이대로 진행할까요? (y/N)"
echo "   y     → 위 계획대로 진행합니다"
echo "   엔터  → 설치를 취소합니다. 아무것도 바뀌지 않습니다"
printf "> "
if ! ask_yes; then
  echo
  echo "취소했습니다. 아무것도 바꾸지 않았습니다."
  echo "다시 하려면 같은 한 줄을 다시 붙여 넣으세요."
  exit 0
fi

HAD_SKILLS=1
[ -d "$DEST" ] || HAD_SKILLS=0
mkdir -p "$DEST"

echo
INSTALLED=(); SKIPPED=(); MOVED=()
for S in "${PICK[@]}"; do
  if [ -d "$DEST/$S" ]; then
    if diff -rq "$SRC/skills/$S" "$DEST/$S" >/dev/null 2>&1; then
      echo "[그대로] $S  이미 같은 판입니다"
      continue
    fi
    echo
    echo "[확인] $S 이(가) 이미 설치돼 있고, 새 판과 내용이 다릅니다."
    echo "   y     → 지금 것을 $S.old-<날짜> 로 옆에 옮기고 새 판을 넣습니다. 지우지 않습니다."
    echo "           ⚠️ 이 폴더 안을 직접 고치셨다면, 고친 내용은 새 판에 없습니다."
    echo "              .old 폴더에 그대로 남아 있으니 필요한 부분을 옮겨 오시면 됩니다."
    echo "   엔터  → 이 스킬만 건너뜁니다. 지금 깔린 것을 그대로 둡니다."
    echo "           나머지 스킬 설치는 계속합니다. 이 스킬은 옛 판으로 남습니다."
    printf "   바꿀까요? (y/N) > "
    if ask_yes; then
      OLD="$S.old-$(date +%Y%m%d-%H%M%S)"
      mv "$DEST/$S" "$DEST/$OLD"
      echo "   옆으로 치워뒀습니다 → $OLD"
      MOVED+=("$OLD")
    else
      echo "   건너뜁니다. $S 은(는) 그대로입니다."
      SKIPPED+=("$S")
      continue
    fi
  fi
  cp -R "$SRC/skills/$S" "$DEST/"
  N=$(find "$DEST/$S" -name '*.md' | wc -l | tr -d ' ')
  echo "[OK] $S  문서 ${N}개"
  INSTALLED+=("$S")
done

echo
echo "== 결과 =="
[ ${#INSTALLED[@]} -gt 0 ] && echo "   설치함:   ${INSTALLED[*]}"
[ ${#SKIPPED[@]} -gt 0 ]   && echo "   건너뜀:   ${SKIPPED[*]}  (옛 판 그대로)"
[ ${#MOVED[@]} -gt 0 ]     && echo "   치워둔 것: ${MOVED[*]}  (자동으로 안 지워집니다. 필요 없으면 직접 지우세요)"

if [ ${#INSTALLED[@]} -eq 0 ]; then
  echo
  echo "새로 설치한 것이 없습니다. 끝냅니다."
  exit 0
fi

echo
if [ "$HAD_SKILLS" = "0" ]; then
  echo "[중요] 클로드 코드를 한 번 껐다 켜 주세요."
  echo "       스킬 폴더가 방금 처음 생겼기 때문입니다. 고장이 아닙니다."
else
  echo "새 창을 열면 바로 잡힙니다. 안 잡히면 클로드 코드를 껐다 켜 주세요."
fi
echo
echo "설치한 곳:   $DEST"
echo "받아온 원본: $SRC"
echo "             (임시 폴더입니다. 컴퓨터를 끄면 사라지니 필요하면 옮겨두세요)"
echo
echo "이렇게 불러 보세요:"
for S in "${INSTALLED[@]}"; do
  case "$S" in
    sns-writing)      echo "   스레드 글 써줘"; echo "   재료 폴더 만들어줘" ;;
    material-harvest) echo "   소재 좀 캐줘" ;;
  esac
done

# 이번에 설치한 스킬 중 예제가 딸린 것이 있으면 알려준다
EXAMPLES=()
for S in "${INSTALLED[@]}"; do
  [ -f "$DEST/$S/EXAMPLE.md" ] && EXAMPLES+=("$DEST/$S/EXAMPLE.md")
done

if [ ${#EXAMPLES[@]} -gt 0 ]; then
  echo
  echo "─────────────────────────────────────────"
  echo "처음이라 막막하시죠?"
  echo
  echo "화면에 실제로 뭐가 나오는지 그대로 보여주는 예제를 넣어뒀습니다."
  echo
  for E in "${EXAMPLES[@]}"; do echo "   $E"; done
  echo
  echo "클로드 코드에서 이렇게 말해도 됩니다:"
  echo "   EXAMPLE.md 읽고 요약해줘"
  echo
  echo "✅ 설치는 이미 끝났습니다. 아래 질문은 예제를 열어볼지만 묻습니다."
  echo "예제를 지금 열어볼까요? (y/N)"
  echo "   y     → 예제 파일을 기본 앱으로 엽니다"
  echo "   엔터  → 열지 않고 끝냅니다. 설치는 취소되지 않습니다. 나중에 위 경로를 여시면 됩니다"
  printf "> "
  if ask_yes; then
    for E in "${EXAMPLES[@]}"; do
      if command -v open >/dev/null 2>&1; then open "$E"
      elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$E"
      else echo "   (여는 명령을 못 찾았습니다. 위 경로를 직접 여세요)"; fi
    done
    echo "   열었습니다."
  else
    echo "   열지 않았습니다. 설치는 그대로 끝났습니다."
  fi
fi
