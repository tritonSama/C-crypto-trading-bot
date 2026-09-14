#Requires -Version 5.1
<#
.SYNOPSIS
  One-click install for creedBuilder TradingView → Jupiter (Solana) bot.

.DESCRIPTION
  Installs Node.js (if needed), cloudflared, npm deps, generates wallet + webhook
  secret, writes creedbuilder/.env, and builds the bot.

.EXAMPLE
  Right-click Install.cmd → Run as administrator
  or:
  .\Setup\Install-Prerequisites.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipNode,
    [switch]$SkipCloudflared
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$BotDir = Join-Path $RepoRoot "creedbuilder"
$EnvFile = Join-Path $BotDir ".env"
$EnvExample = Join-Path $BotDir ".env.example"

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"
}

function Test-Command([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Ensure-Winget {
    if (-not (Test-Command "winget")) {
        throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run Install.cmd."
    }
}

function Install-WingetPackage([string]$Id, [string]$DisplayName) {
    Write-Step "Installing $DisplayName ($Id)"
    $existing = winget list --id $Id --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and ($existing | Select-String -SimpleMatch $Id)) {
        Write-Host "Already installed: $DisplayName"
        return
    }
    winget install --id $Id -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "winget failed installing $Id (exit $LASTEXITCODE)"
    }
    Refresh-Path
}

function New-Secret([int]$Bytes = 24) {
    $buffer = New-Object byte[] $Bytes
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
    return ([Convert]::ToBase64String($buffer) -replace '[^a-zA-Z0-9]', 'x')
}

function Set-EnvValue([string]$Content, [string]$Key, [string]$Value) {
    $line = "$Key=$Value"
    if ($Content -match "(?m)^$Key=") {
        return [regex]::Replace($Content, "(?m)^$Key=.*$", [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $line })
    }
    return ($Content.TrimEnd() + "`r`n$line`r`n")
}

Write-Host "creedBuilder one-click installer (TradingView + Jupiter / Solana)" -ForegroundColor Green
Write-Host "Repo: $RepoRoot"

if (-not (Test-Path $BotDir)) {
    throw "Missing creedbuilder folder at $BotDir"
}

Ensure-Winget

if (-not $SkipNode) {
    Refresh-Path
    $needNode = $true
    if (Test-Command "node") {
        $major = [int]((node -v) -replace '^v', '' -split '\.')[0]
        if ($major -ge 20) {
            Write-Host "Node.js already OK: $(node -v)"
            $needNode = $false
        }
    }
    if ($needNode) {
        Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -DisplayName "Node.js LTS"
        Refresh-Path
    }
}

if (-not $SkipCloudflared) {
    Install-WingetPackage -Id "Cloudflare.cloudflared" -DisplayName "cloudflared (TradingView webhook tunnel)"
    Refresh-Path
}

if (-not (Test-Command "node") -or -not (Test-Command "npm")) {
    throw "Node/npm still not on PATH. Close this window and re-run Install.cmd."
}

Write-Step "Installing npm packages"
Push-Location $BotDir
try {
    npm install
    if ($LASTEXITCODE -ne 0) { throw "npm install failed" }

    Write-Step "Building TypeScript"
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
}
finally {
    Pop-Location
}

Write-Step "Writing creedbuilder/.env"
$legacyEnv = Join-Path $RepoRoot "solana-bot\.env"
if (-not (Test-Path $EnvFile) -and (Test-Path $legacyEnv)) {
    Copy-Item $legacyEnv $EnvFile
    Write-Host "Migrated .env from solana-bot/ → creedbuilder/"
}
if (-not (Test-Path $EnvFile)) {
    Copy-Item $EnvExample $EnvFile
}

$envText = Get-Content $EnvFile -Raw
$secretMatch = [regex]::Match($envText, '(?m)^WEBHOOK_SECRET=(.*)$')
$currentSecret = if ($secretMatch.Success) { $secretMatch.Groups[1].Value.Trim() } else { "" }
if (-not $currentSecret -or $currentSecret -eq "change-me") {
    $envText = Set-EnvValue $envText "WEBHOOK_SECRET" (New-Secret)
}

$keyMatch = [regex]::Match($envText, '(?m)^SOLANA_PRIVATE_KEY=(.*)$')
$currentKey = if ($keyMatch.Success) { $keyMatch.Groups[1].Value.Trim() } else { "" }
$publicKey = ""
if (-not $currentKey) {
    Write-Step "Generating Solana wallet"
    Push-Location $BotDir
    try {
        $walletJson = npm run -s gen-wallet | Out-String
        $wallet = $walletJson | ConvertFrom-Json
        $envText = Set-EnvValue $envText "SOLANA_PRIVATE_KEY" $wallet.privateKeyBase58
        $publicKey = $wallet.publicKey
    }
    finally {
        Pop-Location
    }
} else {
    # derive pubkey for summary via node one-liner
    Push-Location $BotDir
    try {
        $publicKey = node --input-type=module -e "import bs58 from 'bs58'; import {Keypair} from '@solana/web3.js'; const k=Keypair.fromSecretKey(bs58.decode(process.env.K)); console.log(k.publicKey.toBase58());" 2>$null
    } catch { }
    finally { Pop-Location }
}

# Keep safe defaults on first install
$envText = Set-EnvValue $envText "DRY_RUN" "true"
Set-Content -Path $EnvFile -Value $envText -Encoding UTF8

# Re-read secret for user summary
$envText = Get-Content $EnvFile -Raw
$webhookSecret = ([regex]::Match($envText, '(?m)^WEBHOOK_SECRET=(.*)$')).Groups[1].Value.Trim()
if (-not $publicKey) {
    Push-Location $BotDir
    try {
        $env:K = ([regex]::Match($envText, '(?m)^SOLANA_PRIVATE_KEY=(.*)$')).Groups[1].Value.Trim()
        $publicKey = node --input-type=module -e "import bs58 from 'bs58'; import {Keypair} from '@solana/web3.js'; const k=Keypair.fromSecretKey(bs58.decode(process.env.K)); console.log(k.publicKey.toBase58());"
    }
    finally {
        Remove-Item Env:K -ErrorAction SilentlyContinue
        Pop-Location
    }
}

$pinePath = Join-Path $RepoRoot "pine\CreedBuilderSignal.pine"

$done = @"

Install complete.

Wallet (fund with SOL on mainnet for live trades):
  $publicKey

DRY_RUN=true (quotes only). Set DRY_RUN=false in creedbuilder\.env for live Jupiter swaps.

Next (one click start):
  Double-click Start.cmd

TradingView:
  1. Open pine\CreedBuilderSignal.pine and paste into Pine Editor
  2. Add to chart → Create alert (Buy and/or Sell)
  3. Webhook URL from Start.cmd output: https://..../webhook
  4. Alert message:
     {`"secret`":`"$webhookSecret`",`"action`":`"buy`"}
     or
     {`"secret`":`"$webhookSecret`",`"action`":`"sell`"}

Pine file: $pinePath
"@
Write-Host $done -ForegroundColor Green
