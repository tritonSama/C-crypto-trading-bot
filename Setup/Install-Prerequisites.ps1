#Requires -Version 5.1
<#
.SYNOPSIS
  Installs Mario trading-bot prerequisites on Windows via winget.

.DESCRIPTION
  Installs:
    - .NET 6 SDK
    - MongoDB Server (+ Shell)
    - Optionally MongoDB Compass

  Then creates database mario_v1 and seeds collections from MongoDB_Schema/
  if they are empty.

  Coinbase API credentials cannot be installed automatically — fill them in
  MongoDB collection 0_app_settings after this script finishes.

.EXAMPLE
  # From an elevated PowerShell:
  Set-ExecutionPolicy -Scope Process Bypass
  .\Setup\Install-Prerequisites.ps1

.EXAMPLE
  .\Setup\Install-Prerequisites.ps1 -IncludeOptional -SkipMongoSeed
#>
[CmdletBinding()]
param(
    [switch]$IncludeOptional,
    [switch]$SkipDotNet,
    [switch]$SkipMongo,
    [switch]$SkipMongoSeed,
    [string]$MongoDbUrl = "mongodb://127.0.0.1:27017",
    [string]$DatabaseName = "mario_v1"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$SchemaDir = Join-Path $RepoRoot "MongoDB_Schema"

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
        throw "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
    }
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$DisplayName
    )

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

function Wait-ForMongo {
    param([int]$TimeoutSeconds = 90)

    Write-Step "Waiting for MongoDB on $MongoDbUrl"
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            if (Test-Command "mongosh") {
                & mongosh $MongoDbUrl --quiet --eval "db.runCommand({ ping: 1 })" 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) { return }
            }
        } catch { }
        Start-Sleep -Seconds 3
    }
    throw "MongoDB did not become ready within ${TimeoutSeconds}s. Start the MongoDB Windows service and retry with -SkipDotNet -SkipMongo."
}

function Ensure-MongoService {
    $svc = Get-Service -Name "MongoDB" -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host "MongoDB Windows service not found yet (installer may still be finishing)."
        return
    }
    if ($svc.Status -ne "Running") {
        Write-Step "Starting MongoDB service"
        Start-Service MongoDB
    }
}

function Seed-MongoCollections {
    if (-not (Test-Command "mongosh")) {
        throw "mongosh not found on PATH. Install MongoDB.Shell, open a new terminal, and re-run with -SkipDotNet -SkipMongo."
    }

    Wait-ForMongo

    $appSettingsPath = Join-Path $SchemaDir "0_app_settings.json"
    $tradeSettingsPath = Join-Path $SchemaDir "0_trade_settings.json"
    if (-not (Test-Path $appSettingsPath) -or -not (Test-Path $tradeSettingsPath)) {
        throw "Schema files missing under $SchemaDir"
    }

    # Strip extended JSON wrappers so inserts work with plain mongosh.
    $appDoc = Get-Content $appSettingsPath -Raw | ConvertFrom-Json | Select-Object -First 1
    $tradeDoc = Get-Content $tradeSettingsPath -Raw | ConvertFrom-Json | Select-Object -First 1

    $appPayload = @{
        api_key    = [string]$appDoc.api_key
        passphrase = [string]$appDoc.passphrase
        secret     = [string]$appDoc.secret
    } | ConvertTo-Json -Compress

    $tradePayload = @{
        locked                  = [bool]$tradeDoc.locked
        symbol                  = [string]$tradeDoc.symbol
        chain_id                = [string]$tradeDoc.chain_id
        total_cash_to_play      = [string]$tradeDoc.total_cash_to_play.'$numberDecimal'
        cash_per_trade          = [string]$tradeDoc.cash_per_trade.'$numberDecimal'
        ta_history_period       = [int]$tradeDoc.ta_history_period
        wait_buy_to_average_min = [int]$tradeDoc.wait_buy_to_average_min
        wait_buy_to_average_max = [int]$tradeDoc.wait_buy_to_average_max
        duration_candle         = [string]$tradeDoc.duration_candle
    } | ConvertTo-Json -Compress

    $js = @"
const dbName = '$DatabaseName';
const dbx = db.getSiblingDB(dbName);
['0_app_settings','0_trade_settings','0_trade_log'].forEach(c => {
  if (!dbx.getCollectionNames().includes(c)) dbx.createCollection(c);
});
if (dbx.getCollection('0_app_settings').countDocuments({}) === 0) {
  const doc = $appPayload;
  dbx.getCollection('0_app_settings').insertOne(doc);
  print('Seeded 0_app_settings');
} else {
  print('0_app_settings already has data — skipped');
}
if (dbx.getCollection('0_trade_settings').countDocuments({}) === 0) {
  const raw = $tradePayload;
  const doc = Object.assign({}, raw, {
    total_cash_to_play: NumberDecimal(raw.total_cash_to_play),
    cash_per_trade: NumberDecimal(raw.cash_per_trade)
  });
  dbx.getCollection('0_trade_settings').insertOne(doc);
  print('Seeded 0_trade_settings');
} else {
  print('0_trade_settings already has data — skipped');
}
print('Mongo setup complete for ' + dbName);
"@

    $tmp = Join-Path $env:TEMP "mario-mongo-seed.js"
    Set-Content -Path $tmp -Value $js -Encoding UTF8
    Write-Step "Seeding MongoDB database '$DatabaseName'"
    & mongosh $MongoDbUrl --quiet --file $tmp
    if ($LASTEXITCODE -ne 0) {
        throw "mongosh seed script failed (exit $LASTEXITCODE)"
    }
    Remove-Item $tmp -ErrorAction SilentlyContinue
}

# --- main ---
Write-Host "Mario prerequisite installer" -ForegroundColor Green
Write-Host "Repo: $RepoRoot"

if (-not (Test-IsAdmin)) {
    $adminWarn = @"

This script should be run in an elevated PowerShell (Run as administrator)
so MongoDB can install/start its Windows service.
"@
    Write-Host $adminWarn -ForegroundColor Yellow
}

Ensure-Winget

if (-not $SkipDotNet) {
    Install-WingetPackage -Id "Microsoft.DotNet.SDK.6" -DisplayName ".NET 6 SDK"
    Refresh-Path
    if (Test-Command "dotnet") {
        Write-Host "dotnet: $(dotnet --version)"
    } else {
        Write-Host "dotnet installed but not on PATH yet - open a new terminal." -ForegroundColor Yellow
    }
}

if (-not $SkipMongo) {
    # README asks for 5.x; winget currently ships newer server builds which work for this POC.
    Install-WingetPackage -Id "MongoDB.Server" -DisplayName "MongoDB Server"
    Install-WingetPackage -Id "MongoDB.Shell" -DisplayName "MongoDB Shell (mongosh)"
    Ensure-MongoService
}

if ($IncludeOptional) {
    Install-WingetPackage -Id "MongoDB.Compass.Full" -DisplayName "MongoDB Compass"
}

if (-not $SkipMongoSeed) {
    Refresh-Path
    Seed-MongoCollections
}

$doneMsg = @"

Done.

Next (manual - cannot be automated):
  1. Create Coinbase Pro / Advanced Trade API credentials.
  2. Put api_key, secret, passphrase into $DatabaseName.0_app_settings
  3. Set symbol / cash fields in $DatabaseName.0_trade_settings
  4. Create a .NET 6 console app, add this source + NuGet packages, then:
       dotnet run -- run STAGING

Re-run seed only:
  .\Setup\Install-Prerequisites.ps1 -SkipDotNet -SkipMongo
"@
Write-Host $doneMsg -ForegroundColor Green
