param(
  [ValidateSet("project", "user")]
  [string]$Scope = "project",
  [Alias("project-root")]
  [string]$ProjectRoot = (Get-Location).Path,
  [Alias("user-home")]
  [string]$UserHome = $HOME,
  [switch]$Print,
  [switch]$Verify,
  [switch]$Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$IsWindowsHost = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

function Show-Usage {
  @"
Usage: .\scripts\bootstrap-codex-plugin.ps1 [options]

Register this repo as a local Codex marketplace source and write a managed
plugin-enable block for @wiki.

Options:
  -Scope project|user   Where to write config (default: project)
  -ProjectRoot <dir>    Project root for project scope (default: current dir)
  -UserHome <dir>       HOME used for Codex marketplace registration and
                        user-scope config writes (default: current HOME)
  -Print                Print the managed TOML block without writing it
  -Verify               Run scripts/verify-codex-plugin.ps1 after writing
  -Help                 Show this help
"@
}

function Resolve-ExistingDirectory([string]$PathValue) {
  if (-not (Test-Path -LiteralPath $PathValue -PathType Container)) {
    throw "Directory not found: $PathValue"
  }
  return (Resolve-Path -LiteralPath $PathValue).Path
}

function Read-TextIfExists([string]$PathValue) {
  if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
    return ""
  }
  return [System.IO.File]::ReadAllText($PathValue, [System.Text.Encoding]::UTF8)
}

function Write-Utf8NoBom([string]$PathValue, [string]$Text) {
  $parent = Split-Path -Parent $PathValue
  if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($PathValue, $Text, $encoding)
}

function Invoke-WithCodexHome([string]$UserHomeValue, [scriptblock]$Body) {
  $oldHome = $env:HOME
  $oldUserProfile = $env:USERPROFILE
  try {
    $env:HOME = $UserHomeValue
    if ($IsWindowsHost) {
      $env:USERPROFILE = $UserHomeValue
    }
    & $Body
  }
  finally {
    $env:HOME = $oldHome
    $env:USERPROFILE = $oldUserProfile
  }
}

if ($Help) {
  Show-Usage
  exit 0
}

if ($Print -and $Verify) {
  throw "-Print and -Verify cannot be combined"
}

$Root = Resolve-ExistingDirectory (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-ExistingDirectory $ProjectRoot
$UserHome = Resolve-ExistingDirectory $UserHome
$MarketplaceName = "llm-wiki"
$PluginKey = "wiki@$MarketplaceName"
$UserConfig = Join-Path $UserHome ".codex\config.toml"
$ManagedBlock = @"
[plugins."$PluginKey"]
enabled = true
"@

if ($Print) {
  $ManagedBlock
  exit 0
}

$Codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $Codex) {
  throw "codex binary not found in PATH"
}

New-Item -ItemType Directory -Force -Path (Join-Path $UserHome ".codex") | Out-Null

$UserConfigText = Read-TextIfExists $UserConfig
$MarketplacePattern = "(?ms)^\[marketplaces\.$([regex]::Escape($MarketplaceName))\]\r?\n.*?^source = ""(.*?)""$"
$MarketplaceMatch = [regex]::Match($UserConfigText, $MarketplacePattern)
$MarketplaceSource = if ($MarketplaceMatch.Success) { $MarketplaceMatch.Groups[1].Value } else { "" }

if ([string]::IsNullOrWhiteSpace($MarketplaceSource)) {
  Invoke-WithCodexHome $UserHome {
    & $Codex.Source plugin marketplace add $Root
    if ($LASTEXITCODE -ne 0) {
      throw "codex plugin marketplace add failed with exit code $LASTEXITCODE"
    }
  }
}
else {
  $NormalizedMarketplaceSource = $MarketplaceSource
  if (Test-Path -LiteralPath $MarketplaceSource) {
    $NormalizedMarketplaceSource = (Resolve-Path -LiteralPath $MarketplaceSource).Path
  }
  if (-not [string]::Equals($NormalizedMarketplaceSource, $Root, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw @"
Codex marketplace '$MarketplaceName' already points at:
  $MarketplaceSource
This helper will not overwrite another checkout automatically.
Use that checkout, or remove/re-add the marketplace in this Codex home first.
"@
  }
}

if ($Scope -eq "project") {
  $Target = Join-Path $ProjectRoot ".codex\config.toml"
}
else {
  $Target = $UserConfig
}

$Begin = "# BEGIN llm-wiki Codex bootstrap"
$End = "# END llm-wiki Codex bootstrap"
$Managed = "$Begin`n$ManagedBlock`n$End`n"
$Text = Read-TextIfExists $Target
$BlockPattern = "(?ms)^$([regex]::Escape($Begin))\r?\n.*?^$([regex]::Escape($End))\r?\n?"
if ([regex]::IsMatch($Text, $BlockPattern)) {
  $Updated = [regex]::Replace($Text, $BlockPattern, $Managed, 1)
}
else {
  if ($Text -and -not $Text.EndsWith("`n")) {
    $Text += "`n"
  }
  if ($Text) {
    $Text += "`n"
  }
  $Updated = $Text + $Managed
}
Write-Utf8NoBom $Target $Updated

Write-Host "Wrote Codex plugin config:"
Write-Host "  $Target"
Write-Host "Source repo:"
Write-Host "  $Root"
Write-Host "Codex home:"
Write-Host "  $UserHome"

if ($Verify) {
  $VerifyScript = Join-Path $PSScriptRoot "verify-codex-plugin.ps1"
  if ($Scope -eq "project") {
    & $VerifyScript -Scope project -ProjectRoot $ProjectRoot -UserHome $UserHome
  }
  else {
    & $VerifyScript -Scope user -UserHome $UserHome
  }
  exit $LASTEXITCODE
}
