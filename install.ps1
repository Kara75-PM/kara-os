# 카라 OS 스킬 설치 (Windows)
# 사용법:  powershell -ExecutionPolicy Bypass -File install.ps1
#          powershell -ExecutionPolicy Bypass -File install.ps1 -Local     지금 폴더에만
param([switch]$Local)
$ErrorActionPreference = "Stop"

$src = $PSScriptRoot
if ($Local) { $dest = Join-Path (Get-Location) ".claude\skills" }
else        { $dest = Join-Path $env:USERPROFILE ".claude\skills" }

Write-Host "== 카라 OS 스킬 설치 ==" -ForegroundColor Cyan
Write-Host "   받는 곳: $dest"
Write-Host ""

$hadSkills = Test-Path $dest
New-Item -ItemType Directory -Force -Path $dest | Out-Null

foreach ($s in @("sns-writing","source-to-lead")) {
  $target = Join-Path $dest $s
  if (Test-Path $target) {
    $ans = Read-Host "[확인] $s 이(가) 이미 있습니다. 덮어쓸까요? (y/N)"
    if ($ans -ne "y" -and $ans -ne "Y") { Write-Host "       건너뜁니다." -ForegroundColor Yellow; continue }
    Remove-Item -Recurse -Force $target
  }
  Copy-Item -Recurse -Force (Join-Path $src "skills\$s") $dest
  $n = (Get-ChildItem -Recurse -File $target).Count
  Write-Host "[OK] $s  파일 $n 개" -ForegroundColor Green
}

Write-Host ""
if (-not $hadSkills) {
  Write-Host "[중요] 클로드 코드를 한 번 껐다 켜 주세요." -ForegroundColor Red
  Write-Host "       스킬 폴더가 방금 처음 생겼기 때문입니다. 고장이 아닙니다."
} else {
  Write-Host "다시 켜지 않아도 바로 잡힙니다."
}
Write-Host ""
Write-Host "이렇게 불러 보세요:" -ForegroundColor Cyan
Write-Host "   스레드 글 써줘"
Write-Host "   이 소재로 콘텐츠 만들어줘. 신청은 (주소)로 받을 거야"
