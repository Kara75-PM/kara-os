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
# 이 스크립트는 파일을 지우지 않습니다. 옛 판은 스킬 폴더 바깥의 skills-backup/ 으로 옮겨 둘 뿐입니다.
# 무엇을 할지 먼저 보여주고 「y」를 받은 뒤에만 설치합니다. 그냥 엔터는 언제나 「안 한다」입니다.
# 같은 이름이 이미 있으면, 하나씩 따로 묻고 <이름>.old-날짜 로 옆에 치워둡니다.

# 「sh install.sh」·「zsh install.sh」로 실행하면 아래 배열 문법에서 알 수 없는 오류로 멈춘다.
# bash 가 있으면 bash 로 다시 실행하고, 없으면 무엇을 하면 되는지 알려준다.
if [ -z "$BASH_VERSION" ]; then
  if [ -f "$0" ] && command -v bash >/dev/null 2>&1; then exec bash "$0" "$@"; fi
  echo "[중단] 이 스크립트는 bash 로 실행해야 합니다:  bash install.sh"
  exit 1
fi
set -e

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/skills"
PICK=(); ALL=""; LIST=""

# 이미 고른 것인지. 같은 것을 두 번 골라도 계획에 두 줄로 나오지 않게 한다. (bash 3.2 엔 연관 배열이 없다)
picked() {
  local x
  for x in "${PICK[@]}"; do [ "$x" = "$1" ] && return 0; done
  return 1
}

for a in "$@"; do
  case "$a" in
    --local) DEST="$(pwd)/.claude/skills" ;;
    --all)   ALL=1 ;;
    --list)  LIST=1 ;;
    -*)      echo "모르는 옵션: $a"; echo "쓸 수 있는 것: --all  --local  --list  또는 스킬 이름"; exit 1 ;;
    *)
      # 탭 자동완성으로 붙는 「sns-writing/」·「skills/sns-writing/」도 이름만 받는다.
      # (맥의 cp -R 은 끝에 / 가 붙으면 폴더가 아니라 안의 파일을 쏟아 넣는다)
      while [ "${a%/}" != "$a" ]; do a="${a%/}"; done
      a="${a##*/}"
      picked "$a" || PICK+=("$a") ;;
  esac
done

# 옛 판은 스킬 폴더 「바깥」에 둔다. 안에 두면 클로드 코드가 옛 판도 스킬로 읽어 같은 스킬이 둘 잡힌다.
BACKUP="$(dirname "$DEST")/skills-backup"

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
          | sed 's/^[*> ]*//;s/\*\*//g')
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
  ANS="${ANS//,/ }"   # 「1,2」처럼 쉼표로 쳐도 받는다
  if [ -z "${ANS// /}" ]; then
    PICK=("${AVAIL[@]}")
  else
    for n in $ANS; do
      case "$n" in ''|*[!0-9]*) echo "[중단] '$n' 은 번호가 아닙니다. 아무것도 설치하지 않았습니다."; exit 1 ;; esac
      idx=$((10#$n - 1))   # 「08」을 8진수로 읽어 멈추지 않게 10진수로 못 박는다
      if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#AVAIL[@]} ]; then picked "${AVAIL[$idx]}" || PICK+=("${AVAIL[$idx]}")
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

# 예전 설치기는 옛 판을 스킬 폴더 「안」에 남겼다. 알려만 주고 건드리지는 않는다.
LEFTOVER=()
for d in "$DEST"/*.old-*/; do
  [ -f "$d/SKILL.md" ] && LEFTOVER+=("$(basename "$d")")
done
if [ ${#LEFTOVER[@]} -gt 0 ]; then
  echo "   ⚠️ 스킬 폴더 안에 예전에 치워둔 옛 판이 남아 있습니다: ${LEFTOVER[*]}"
  echo "      클로드 코드가 같은 스킬을 두 번 잡을 수 있습니다. 이 스크립트는 건드리지 않습니다."
  echo "      필요 없으면 지우시고, 남겨두려면 $BACKUP 로 옮기세요."
  echo
fi

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
    echo "   y     → 지금 것을 $BACKUP/$S.old-<날짜> 로 옮기고 새 판을 넣습니다. 지우지 않습니다."
    echo "           ⚠️ 이 폴더 안을 직접 고치셨다면, 고친 내용은 새 판에 없습니다."
    echo "              옮겨 둔 옛 판에 그대로 남아 있으니 필요한 부분을 옮겨 오시면 됩니다."
    echo "   엔터  → 이 스킬만 건너뜁니다. 지금 깔린 것을 그대로 둡니다."
    echo "           나머지 스킬 설치는 계속합니다. 이 스킬은 옛 판으로 남습니다."
    printf "   바꿀까요? (y/N) > "
    if ask_yes; then
      OLD="$S.old-$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$BACKUP"
      mv "$DEST/$S" "$BACKUP/$OLD"
      echo "   치워뒀습니다 → $BACKUP/$OLD"
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
[ ${#MOVED[@]} -gt 0 ]     && echo "   치워둔 것: ${MOVED[*]}  ($BACKUP 안. 자동으로 안 지워집니다. 필요 없으면 직접 지우세요)"

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
TMPROOT="${TMPDIR:-/tmp}"
case "$SRC" in
  "${TMPROOT%/}"/*|/tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*)
    echo "             (임시 폴더입니다. 컴퓨터를 끄면 사라지니 필요하면 옮겨두세요)" ;;
esac
echo
echo "이렇게 불러 보세요:"
for S in "${INSTALLED[@]}"; do
  case "$S" in
    sns-writing)      echo "   스레드 글 써줘"; echo "   재료 폴더 만들어줘" ;;
    material-harvest) echo "   소재 좀 캐줘" ;;
    source-to-lead)   echo "   이 소재로 콘텐츠 만들어줘" ;;
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
    # 여는 데 실패해도(화면 없는 리눅스·WSL, .md 에 연결된 앱 없음) 설치는 끝났으니 오류로 멈추지 않는다.
    OPENER=""
    if command -v open >/dev/null 2>&1; then OPENER=open
    elif command -v xdg-open >/dev/null 2>&1; then OPENER=xdg-open; fi
    if [ -z "$OPENER" ]; then
      echo "   (여는 명령을 못 찾았습니다. 위 경로를 직접 여세요. 설치는 그대로 끝났습니다)"
    else
      OPEN_FAIL=0
      for E in "${EXAMPLES[@]}"; do "$OPENER" "$E" >/dev/null 2>&1 || OPEN_FAIL=1; done
      if [ "$OPEN_FAIL" = "0" ]; then echo "   열었습니다."
      else echo "   (열지 못한 파일이 있습니다. 위 경로를 직접 여세요. 설치는 그대로 끝났습니다)"; fi
    fi
  else
    echo "   열지 않았습니다. 설치는 그대로 끝났습니다."
  fi
fi
