# 카라 OS 스킬 설치 (Windows)
#
#   powershell -ExecutionPolicy Bypass -File install.ps1                    물어보고 고릅니다
#   powershell -ExecutionPolicy Bypass -File install.ps1 -All               전부
#   powershell -ExecutionPolicy Bypass -File install.ps1 sns-writing        이것만
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Local             지금 폴더에만
#   powershell -ExecutionPolicy Bypass -File install.ps1 -List              보기만
#
# 이 스크립트는 파일을 지우지 않습니다.
# 무엇을 할지 먼저 보여주고 「y」를 받은 뒤에만 설치합니다. 그냥 엔터는 언제나 「안 한다」입니다.
# 같은 이름이 이미 있으면, 하나씩 따로 묻고 <이름>.old-날짜 로 옆에 치워둡니다.
param(
  [switch]$Local, [switch]$All, [switch]$List,
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Names
)
$ErrorActionPreference = "Stop"

$src = $PSScriptRoot
if ($Local) { $dest = Join-Path (Get-Location) ".claude\skills" }
else        { $dest = Join-Path $env:USERPROFILE ".claude\skills" }

$avail = @()
Get-ChildItem -Directory (Join-Path $src "skills") -ErrorAction SilentlyContinue | ForEach-Object {
  if (Test-Path (Join-Path $_.FullName "SKILL.md")) { $avail += $_.Name }
}
if ($avail.Count -eq 0) {
  Write-Host "[중단] skills 안에 설치할 스킬이 없습니다." -ForegroundColor Red
  Write-Host "       저장소를 받은 폴더 안에서 실행해야 합니다."
  exit 1
}

function Show-List {
  Write-Host "이 저장소에 들어 있는 스킬:"
  for ($i=0; $i -lt $avail.Count; $i++) {
    $rp = Join-Path $src ("skills\" + $avail[$i] + "\README.md")
    $one = ""
    if (Test-Path $rp) {
      $one = (Get-Content $rp -TotalCount 9 | Select-Object -Skip 4 |
              Where-Object { $_ -match "[가-힣]" } | Select-Object -First 1)
      $one = ($one -replace '^[*> ]*','' -replace '\*\*','')
      if ($one.Length -gt 56) { $one = $one.Substring(0,56) }
    }
    "  {0}) {1,-16} {2}" -f ($i+1), $avail[$i], $one | Write-Host
  }
}

# y 로 답했을 때만 「예」. 엔터·그 밖의 글자는 전부 「아니오」. 한글 자판 그대로 친 y(ㅛ)도 받는다.
function Ask-Yes([string]$prompt) {
  $a = Read-Host $prompt
  return @('y','Y','yes','Yes','YES','ㅛ') -contains $a
}

# 두 폴더의 파일 목록과 내용이 모두 같으면 $true
function Same-Dir([string]$a, [string]$b) {
  $ha = Get-ChildItem -Recurse -File $a | ForEach-Object { $_.FullName.Substring($a.Length) + "|" + (Get-FileHash $_.FullName).Hash } | Sort-Object
  $hb = Get-ChildItem -Recurse -File $b | ForEach-Object { $_.FullName.Substring($b.Length) + "|" + (Get-FileHash $_.FullName).Hash } | Sort-Object
  return (($ha -join "`n") -eq ($hb -join "`n"))
}

if ($List) { Show-List; exit 0 }

$pick = @()
foreach ($n in $Names) {
  if ($n -like '-*') {
    Write-Host "모르는 옵션: $n" -ForegroundColor Red
    Write-Host "쓸 수 있는 것: -All  -Local  -List  또는 스킬 이름"
    Write-Host "(맥용 --all / --list 가 아니라 앞에 붙임표 하나입니다)"
    exit 1
  }
}
if ($All) {
  $pick = $avail
} elseif ($Names -and $Names.Count -gt 0) {
  foreach ($n in $Names) {
    if ($avail -notcontains $n) {
      Write-Host "[중단] '$n' 는 이 저장소에 없습니다." -ForegroundColor Red
      Write-Host ""; Show-List; exit 1
    }
    $pick += $n
  }
} else {
  Show-List
  Write-Host ""
  $ans = Read-Host "무엇을 설치할까요? 번호를 띄어쓰기로 (전부 설치는 그냥 엔터 — 설치 전에 한 번 더 묻습니다)"
  if ([string]::IsNullOrWhiteSpace($ans)) { $pick = $avail }
  else {
    foreach ($n in ($ans -split '\s+')) {
      if ($n -notmatch '^\d+$') { Write-Host "[중단] '$n' 은 번호가 아닙니다. 아무것도 설치하지 않았습니다." -ForegroundColor Red; exit 1 }
      $idx = [int]$n - 1
      if ($idx -lt 0 -or $idx -ge $avail.Count) { Write-Host "[중단] $n 번은 없는 번호입니다. 아무것도 설치하지 않았습니다." -ForegroundColor Red; exit 1 }
      $pick += $avail[$idx]
    }
  }
}

# ── 설치 계획 — 아무것도 바꾸기 전에 보여주고 묻는다 ──
Write-Host ""
Write-Host "== 설치 계획 — 아직 아무것도 바꾸지 않았습니다 ==" -ForegroundColor Cyan
Write-Host "   받는 곳: $dest"
Write-Host ""
$newN = 0; $diffN = 0
foreach ($s in $pick) {
  $target = Join-Path $dest $s
  if (-not (Test-Path $target)) { Write-Host "   [새로 설치]   $s"; $newN++ }
  elseif (Same-Dir (Join-Path $src "skills\$s") $target) { Write-Host "   [이미 같은 판] $s  — 건드리지 않습니다" }
  else { Write-Host "   [이미 있음]   $s  — 바꿀지 따로 한 번 더 묻습니다" -ForegroundColor Yellow; $diffN++ }
}
Write-Host ""
if (($newN + $diffN) -eq 0) {
  Write-Host "고른 스킬이 모두 이미 같은 판으로 설치돼 있습니다. 바꿀 것이 없어 끝냅니다."
  exit 0
}
Write-Host "이대로 진행할까요? (y/N)"
Write-Host "   y     → 위 계획대로 진행합니다"
Write-Host "   엔터  → 설치를 취소합니다. 아무것도 바뀌지 않습니다"
if (-not (Ask-Yes ">")) {
  Write-Host ""
  Write-Host "취소했습니다. 아무것도 바꾸지 않았습니다." -ForegroundColor Yellow
  Write-Host "다시 하려면 같은 한 줄을 다시 붙여 넣으세요."
  exit 0
}

$hadSkills = Test-Path $dest
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Write-Host ""
$installed = @(); $skipped = @(); $moved = @()
foreach ($s in $pick) {
  $target = Join-Path $dest $s
  if (Test-Path $target) {
    if (Same-Dir (Join-Path $src "skills\$s") $target) { Write-Host "[그대로] $s  이미 같은 판입니다"; continue }
    Write-Host ""
    Write-Host "[확인] $s 이(가) 이미 설치돼 있고, 새 판과 내용이 다릅니다." -ForegroundColor Yellow
    Write-Host "   y     → 지금 것을 $s.old-<날짜> 로 옆에 옮기고 새 판을 넣습니다. 지우지 않습니다."
    Write-Host "           ⚠️ 이 폴더 안을 직접 고치셨다면, 고친 내용은 새 판에 없습니다."
    Write-Host "              .old 폴더에 그대로 남아 있으니 필요한 부분을 옮겨 오시면 됩니다."
    Write-Host "   엔터  → 이 스킬만 건너뜁니다. 지금 깔린 것을 그대로 둡니다."
    Write-Host "           나머지 스킬 설치는 계속합니다. 이 스킬은 옛 판으로 남습니다."
    if (Ask-Yes "   바꿀까요? (y/N)") {
      $old = "$s.old-" + (Get-Date -Format "yyyyMMdd-HHmmss")
      Rename-Item -Path $target -NewName $old
      Write-Host "   옆으로 치워뒀습니다 -> $old"
      $moved += $old
    } else {
      Write-Host "   건너뜁니다. $s 은(는) 그대로입니다."
      $skipped += $s
      continue
    }
  }
  Copy-Item -Recurse (Join-Path $src "skills\$s") $dest
  $n = (Get-ChildItem -Recurse -File -Filter *.md $target).Count
  Write-Host "[OK] $s  문서 $n 개" -ForegroundColor Green
  $installed += $s
}

Write-Host ""
Write-Host "== 결과 ==" -ForegroundColor Cyan
if ($installed.Count -gt 0) { Write-Host "   설치함:   $($installed -join ' ')" }
if ($skipped.Count -gt 0)   { Write-Host "   건너뜀:   $($skipped -join ' ')  (옛 판 그대로)" }
if ($moved.Count -gt 0)     { Write-Host "   치워둔 것: $($moved -join ' ')  (자동으로 안 지워집니다. 필요 없으면 직접 지우세요)" }
if ($installed.Count -eq 0) {
  Write-Host ""
  Write-Host "새로 설치한 것이 없습니다. 끝냅니다."
  exit 0
}

Write-Host ""
if (-not $hadSkills) {
  Write-Host "[중요] 클로드 코드를 한 번 껐다 켜 주세요." -ForegroundColor Red
  Write-Host "       스킬 폴더가 방금 처음 생겼기 때문입니다. 고장이 아닙니다."
} else {
  Write-Host "새 창을 열면 바로 잡힙니다. 안 잡히면 클로드 코드를 껐다 켜 주세요."
}
Write-Host ""
Write-Host "설치한 곳:   $dest"
Write-Host "받아온 원본: $src"
Write-Host "             (임시 폴더입니다. 컴퓨터를 끄면 사라지니 필요하면 옮겨두세요)"
Write-Host ""
Write-Host "이렇게 불러 보세요:" -ForegroundColor Cyan
foreach ($s in $installed) {
  if ($s -eq "sns-writing")      { Write-Host "   스레드 글 써줘"; Write-Host "   재료 폴더 만들어줘" }
  if ($s -eq "material-harvest") { Write-Host "   소재 좀 캐줘" }
}

# 이번에 설치한 스킬 중 예제가 딸린 것이 있으면 알려준다
$examples = @()
foreach ($s in $installed) {
  $e = Join-Path $dest "$s\EXAMPLE.md"
  if (Test-Path $e) { $examples += $e }
}

if ($examples.Count -gt 0) {
  Write-Host ""
  Write-Host "─────────────────────────────────────────"
  Write-Host "처음이라 막막하시죠?" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "화면에 실제로 뭐가 나오는지 그대로 보여주는 예제를 넣어뒀습니다."
  Write-Host ""
  foreach ($e in $examples) { Write-Host "   $e" }
  Write-Host ""
  Write-Host "클로드 코드에서 이렇게 말해도 됩니다:" -ForegroundColor Cyan
  Write-Host "   EXAMPLE.md 읽고 요약해줘"
  Write-Host ""
  Write-Host "✅ 설치는 이미 끝났습니다. 아래 질문은 예제를 열어볼지만 묻습니다." -ForegroundColor Green
  Write-Host "예제를 지금 열어볼까요? (y/N)"
  Write-Host "   y     → 예제 파일을 기본 앱으로 엽니다"
  Write-Host "   엔터  → 열지 않고 끝냅니다. 설치는 취소되지 않습니다. 나중에 위 경로를 여시면 됩니다"
  if (Ask-Yes ">") {
    foreach ($e in $examples) { Invoke-Item $e }
    Write-Host "   열었습니다."
  } else {
    Write-Host "   열지 않았습니다. 설치는 그대로 끝났습니다."
  }
}
