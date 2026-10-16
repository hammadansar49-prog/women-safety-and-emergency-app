param([int]$Port = 8080, [switch]$Development)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
# Keep Flutter compilation scratch files beside this project rather than on C:.
$previewTemp = Join-Path $projectRoot 'build\preview-temp'
New-Item -ItemType Directory -Force -Path $previewTemp | Out-Null
$env:TEMP = $previewTemp
$env:TMP = $previewTemp
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not on PATH. Install Flutter or add its bin directory to PATH.'
}
Write-Host "SafeHer browser preview: http://localhost:$Port"
if ($Development) {
    Write-Host 'Development mode: keep this terminal open. r reloads, R restarts, q stops.'
    & flutter run -d web-server --web-hostname 127.0.0.1 --web-port $Port
    exit $LASTEXITCODE
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw 'Python is required to serve this preview. Alternatively use -Development for the Flutter development server.'
}
& flutter build web --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Keep this terminal open. Ctrl+C stops the preview. Rerun the launcher after code changes.'
& python -m http.server $Port --bind 127.0.0.1 --directory (Join-Path $projectRoot 'build\web')
exit $LASTEXITCODE
