#Requires -Version 5.1
<#
.SYNOPSIS
  Starts the Jupiter webhook bot and a Cloudflare quick tunnel for TradingView.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$BotDir = Join-Path $RepoRoot "creedbuilder"
$EnvFile = Join-Path $BotDir ".env"
$LogDir = Join-Path $RepoRoot "Setup\logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

Refresh-Path

if (-not (Test-Path $EnvFile)) {
    throw "Missing creedbuilder\.env — run Install.cmd first."
}

$portMatch = [regex]::Match((Get-Content $EnvFile -Raw), '(?m)^PORT=(.*)$')
$port = if ($portMatch.Success -and $portMatch.Groups[1].Value.Trim()) { $portMatch.Groups[1].Value.Trim() } else { "8787" }

$secret = ([regex]::Match((Get-Content $EnvFile -Raw), '(?m)^WEBHOOK_SECRET=(.*)$')).Groups[1].Value.Trim()

Write-Host "Starting creedBuilder on port $port ..." -ForegroundColor Cyan

$botLog = Join-Path $LogDir "bot.out.log"
$botErr = Join-Path $LogDir "bot.err.log"
$tunnelLog = Join-Path $LogDir "tunnel.out.log"
$tunnelErr = Join-Path $LogDir "tunnel.err.log"

$bot = Start-Process -FilePath "cmd.exe" -ArgumentList @("/c", "npm run start") -WorkingDirectory $BotDir `
    -RedirectStandardOutput $botLog -RedirectStandardError $botErr -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 2
if ($bot.HasExited) {
    Write-Host (Get-Content $botErr -Raw -ErrorAction SilentlyContinue)
    throw "Bot failed to start. See $botErr"
}

Write-Host "Starting Cloudflare quick tunnel ..." -ForegroundColor Cyan
if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
    Stop-Process -Id $bot.Id -Force -ErrorAction SilentlyContinue
    throw "cloudflared not found. Re-run Install.cmd."
}

$tunnel = Start-Process -FilePath "cloudflared" `
    -ArgumentList @("tunnel", "--url", "http://127.0.0.1:$port", "--no-autoupdate") `
    -RedirectStandardOutput $tunnelLog -RedirectStandardError $tunnelErr -PassThru -WindowStyle Hidden -NoNewWindow

$publicUrl = $null
$deadline = (Get-Date).AddSeconds(45)
while ((Get-Date) -lt $deadline -and -not $publicUrl) {
    Start-Sleep -Seconds 1
    $combined = ""
    if (Test-Path $tunnelErr) { $combined += Get-Content $tunnelErr -Raw -ErrorAction SilentlyContinue }
    if (Test-Path $tunnelLog) { $combined += Get-Content $tunnelLog -Raw -ErrorAction SilentlyContinue }
    $m = [regex]::Match($combined, 'https://[a-zA-Z0-9-]+\.trycloudflare\.com')
    if ($m.Success) { $publicUrl = $m.Value }
}

if (-not $publicUrl) {
    Write-Host "Tunnel started but URL not parsed yet. Check $tunnelErr" -ForegroundColor Yellow
} else {
    $webhook = "$publicUrl/webhook"
    Write-Host ""
    Write-Host "Bot PID: $($bot.Id)   Tunnel PID: $($tunnel.Id)" -ForegroundColor Green
    Write-Host "Health:  $publicUrl/health"
    Write-Host "Webhook: $webhook" -ForegroundColor Green
    Write-Host ""
    Write-Host "TradingView alert messages:" -ForegroundColor Cyan
    Write-Host "{`"secret`":`"$secret`",`"action`":`"buy`"}"
    Write-Host "{`"secret`":`"$secret`",`"action`":`"sell`"}"
    Write-Host ""
    Write-Host "Press Ctrl+C to stop." -ForegroundColor Yellow

    try {
        Set-Clipboard -Value $webhook -ErrorAction SilentlyContinue
        Write-Host "(Webhook URL copied to clipboard)"
    } catch { }
}

try {
    Wait-Process -Id $bot.Id
} finally {
    if ($tunnel -and -not $tunnel.HasExited) { Stop-Process -Id $tunnel.Id -Force -ErrorAction SilentlyContinue }
    if ($bot -and -not $bot.HasExited) { Stop-Process -Id $bot.Id -Force -ErrorAction SilentlyContinue }
}
