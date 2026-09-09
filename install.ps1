# 카라 OS 스킬 설치 (Windows)
#
#   powershell -ExecutionPolicy Bypass -File install.ps1                    물어보고 고릅니다
#   powershell -ExecutionPolicy Bypass -File install.ps1 -All               전부
#   powershell -ExecutionPolicy Bypass -File install.ps1 sns-writing        이것만
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Local             지금 폴더에만
#   powershell -ExecutionPolicy Bypass -File install.ps1 -List              보기만
#
# 이 스크립트는 파일을 지우지 않습니다.
# 같은 이름이 이미 있으면, 허락을 받은 뒤 <이름>.old-날짜 로 옆에 치워둡니다.
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
  $ans = Read-Host "무엇을 설치할까요? 번호를 띄어쓰기로 (전부 설치는 그냥 엔터)"
  if ([string]::IsNullOrWhiteSpace($ans)) { $pick = $avail }
  else {
    foreach ($n in ($ans -split '\s+')) {
      if ($n -notmatch '^\d+$') { Write-Host "[중단] '$n' 은 번호가 아닙니다." -ForegroundColor Red; exit 1 }
      $idx = [int]$n - 1
      if ($idx -lt 0 -or $idx -ge $avail.Count) { Write-Host "[중단] $n 번은 없는 번호입니다." -ForegroundColor Red; exit 1 }
      $pick += $avail[$idx]
    }
  }
}

Write-Host ""
Write-Host "== 카라 OS 스킬 설치 ==" -ForegroundColor Cyan
Write-Host "   받는 곳: $dest"
Write-Host ""

$hadSkills = Test-Path $dest
New-Item -ItemType Directory -Force -Path $dest | Out-Null

foreach ($s in $pick) {
  $target = Join-Path $dest $s
  if (Test-Path $target) {
    Write-Host "[확인] $s 이(가) 이미 있습니다." -ForegroundColor Yellow
    Write-Host "       덮어쓰면 기존 폴더를 $s.old-<날짜> 로 옆에 치워둡니다. 지우지 않습니다."
    $ans = Read-Host "       진행할까요? (y/N)"
    if ($ans -ne "y" -and $ans -ne "Y") { Write-Host "       건너뜁니다."; continue }
    $old = "$s.old-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    Rename-Item -Path $target -NewName $old
    Write-Host "       옆으로 치워뒀습니다 -> $old"
  }
  Copy-Item -Recurse (Join-Path $src "skills\$s") $dest
  $n = (Get-ChildItem -Recurse -File -Filter *.md $target).Count
  Write-Host "[OK] $s  문서 $n 개" -ForegroundColor Green
}

Write-Host ""
if (-not $hadSkills) {
  Write-Host "[중요] 클로드 코드를 한 번 껐다 켜 주세요." -ForegroundColor Red
  Write-Host "       스킬 폴더가 방금 처음 생겼기 때문입니다. 고장이 아닙니다."
} else {
  Write-Host "다시 켜지 않아도 바로 잡힙니다."
}
Write-Host ""
Write-Host "설치한 곳:   $dest"
Write-Host "받아온 원본: $src"
Write-Host "             (임시 폴더입니다. 컴퓨터를 끄면 사라지니 필요하면 옮겨두세요)"
Write-Host ""
Write-Host "이렇게 불러 보세요:" -ForegroundColor Cyan
Write-Host "   스레드 글 써줘"
Write-Host "   재료 폴더 만들어줘"

# 예제가 딸린 스킬이 있으면 알려준다
$examples = @()
foreach ($s in $pick) {
  $e = Join-Path $dest "$s\EXAMPLE.md"
  if (Test-Path $e) { $examples += $e }
}

if ($examples.Count -gt 0) {
  Write-Host ""
  Write-Host "─────────────────────────────────────────"
  Write-Host "처음이라 막막하시죠?" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "설치부터 글 한 편이 나올 때까지 화면에 실제로 뭐가 나오는지"
  Write-Host "그대로 보여주는 예제를 넣어뒀습니다."
  Write-Host ""
  foreach ($e in $examples) { Write-Host "   $e" }
  Write-Host ""
  Write-Host "클로드 코드에서 이렇게 말해도 됩니다:" -ForegroundColor Cyan
  Write-Host "   EXAMPLE.md 읽고 요약해줘"
  Write-Host ""
  $ans = Read-Host "지금 열어볼까요? (y/N)"
  if ($ans -eq "y" -or $ans -eq "Y") {
    foreach ($e in $examples) { Invoke-Item $e }
    Write-Host "   열었습니다."
  } else {
    Write-Host "   나중에 보시려면 위 경로를 여시면 됩니다."
  }
}
