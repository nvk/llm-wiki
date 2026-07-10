param(
  [ValidateSet("project", "user")]
  [string]$Scope = "user",
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

Register this repo as a local Codex marketplace source, install @wiki and the
bundled `$wiki-query preset into the Codex plugin cache, and enable the plugin
in the user config.

Options:
  -Scope user           Plugin enablement scope (default: user). Codex 0.144
                        does not load plugin enablement from project config.
  -ProjectRoot <dir>    Working directory for the optional verification probe
  -UserHome <dir>       HOME used for Codex marketplace registration and
                        user-scope config writes (default: current HOME)
  -Print                Print the managed TOML block without writing it
  -Verify               Run scripts/verify-codex-plugin.ps1 after installation
  -Help                 Show this help
"@
}

function Resolve-ExistingDirectory([string]$PathValue) {
  if (-not (Test-Path -LiteralPath $PathValue -PathType Container)) {
    throw "Directory not found: $PathValue"
  }
  return (Resolve-Path -LiteralPath $PathValue).Path
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

function Invoke-CodexJson([System.Management.Automation.CommandInfo]$CodexCommand, [string[]]$Arguments) {
  $Output = & $CodexCommand.Source @Arguments
  $ExitCode = $LASTEXITCODE
  $Text = ($Output | Out-String).Trim()
  if ($ExitCode -ne 0) {
    throw "codex $($Arguments -join ' ') failed with exit code $ExitCode`n$Text"
  }
  try {
    return $Text | ConvertFrom-Json
  }
  catch {
    throw "codex $($Arguments -join ' ') returned invalid JSON`n$Text"
  }
}

function Normalize-PathForComparison([string]$PathValue) {
  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    return ""
  }
  if (Test-Path -LiteralPath $PathValue) {
    $PathValue = (Resolve-Path -LiteralPath $PathValue).Path
  }
  else {
    $PathValue = [System.IO.Path]::GetFullPath($PathValue)
  }
  return $PathValue.TrimEnd([char[]]@('\', '/'))
}

function Test-SamePath([string]$Left, [string]$Right) {
  if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
    return $false
  }
  return [string]::Equals(
    (Normalize-PathForComparison $Left),
    (Normalize-PathForComparison $Right),
    [System.StringComparison]::OrdinalIgnoreCase
  )
}

if ($Help) {
  Show-Usage
  exit 0
}

if ($Scope -eq "project") {
  throw "Project-scoped plugin enablement is not supported by Codex 0.144. Use -Scope user; plugin hooks can still be enabled or disabled separately."
}

if ($Print -and $Verify) {
  throw "-Print and -Verify cannot be combined"
}

$Root = Resolve-ExistingDirectory (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-ExistingDirectory $ProjectRoot
$UserHome = Resolve-ExistingDirectory $UserHome
$MarketplaceName = "llm-wiki"
$PluginKey = "wiki@$MarketplaceName"
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

$MarketplaceData = Invoke-WithCodexHome $UserHome {
  Invoke-CodexJson $Codex @("plugin", "marketplace", "list", "--json")
}
$Marketplace = @($MarketplaceData.marketplaces) |
  Where-Object { $_.name -eq $MarketplaceName } |
  Select-Object -First 1

if ($null -eq $Marketplace) {
  Invoke-WithCodexHome $UserHome {
    $Output = & $Codex.Source plugin marketplace add $Root 2>&1
    $ExitCode = $LASTEXITCODE
    if ($ExitCode -ne 0) {
      throw "codex plugin marketplace add failed with exit code $ExitCode`n$($Output | Out-String)"
    }
    $Output | ForEach-Object { Write-Host $_ }
  }
}
else {
  $MarketplaceSource = ""
  if ($Marketplace.marketplaceSource -and $Marketplace.marketplaceSource.source) {
    $MarketplaceSource = [string]$Marketplace.marketplaceSource.source
  }
  elseif ($Marketplace.root) {
    $MarketplaceSource = [string]$Marketplace.root
  }
  if (-not (Test-SamePath $MarketplaceSource $Root)) {
    throw @"
Codex marketplace '$MarketplaceName' already points at:
  $MarketplaceSource
This helper will not overwrite another checkout automatically.
Use that checkout, or remove/re-add the marketplace in this Codex home first.
"@
  }
}

$InstallData = Invoke-WithCodexHome $UserHome {
  Invoke-CodexJson $Codex @("plugin", "add", $PluginKey, "--json")
}
if (-not $InstallData.installedPath) {
  throw "codex plugin add did not return installedPath"
}

$UserConfig = Join-Path $UserHome ".codex\config.toml"
Write-Host "Installed Codex plugin:"
Write-Host "  $PluginKey"
Write-Host "Installed cache:"
Write-Host "  $($InstallData.installedPath)"
Write-Host "Enabled scope:"
Write-Host "  $Scope"
Write-Host "Codex plugin config:"
Write-Host "  $UserConfig"
Write-Host "Source repo:"
Write-Host "  $Root"
Write-Host "Codex home:"
Write-Host "  $UserHome"

if ($Verify) {
  $VerifyScript = Join-Path $PSScriptRoot "verify-codex-plugin.ps1"
  & $VerifyScript -Scope user -ProjectRoot $ProjectRoot -UserHome $UserHome
  exit $LASTEXITCODE
}
