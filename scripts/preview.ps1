param([int]$Port = 8080)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not on PATH. Install Flutter or add its bin directory to PATH.'
}
Write-Host "SafeHer browser preview: http://localhost:$Port"
Write-Host 'Keep this terminal open. Press r to reload, R to restart, q to stop.'
& flutter run -d web-server --web-hostname 127.0.0.1 --web-port $Port
exit $LASTEXITCODE
