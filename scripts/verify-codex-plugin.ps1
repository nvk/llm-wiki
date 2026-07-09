param(
  [ValidateSet("project", "user")]
  [string]$Scope = "project",
  [Alias("project-root")]
  [string]$ProjectRoot = (Get-Location).Path,
  [Alias("user-home")]
  [string]$UserHome = $HOME,
  [switch]$Help
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$IsWindowsHost = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT

function Show-Usage {
  @"
Usage: .\scripts\verify-codex-plugin.ps1 [options]

Verify that Codex resolves @wiki to this repo's generated Codex wiki skill.

Options:
  -Scope project|user   Verify project or user install (default: project)
  -ProjectRoot <dir>    Project root for project scope (default: current dir)
  -UserHome <dir>       HOME used for Codex config lookup (default: current HOME)
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

function Test-TextContainsPath([string]$Text, [string]$PathValue) {
  $forward = $PathValue -replace "\\", "/"
  return $Text.Contains($PathValue) -or $Text.Contains($forward)
}

if ($Help) {
  Show-Usage
  exit 0
}

$Root = Resolve-ExistingDirectory (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-ExistingDirectory $ProjectRoot
$UserHome = Resolve-ExistingDirectory $UserHome
$MarketplaceName = "llm-wiki"
$PluginKey = "wiki@$MarketplaceName"
$ExpectedSkillPath = Join-Path $Root "plugins\llm-wiki\skills\wiki\SKILL.md"
$ProbeDir = Join-Path $Root ".tmp\codex-runtime-probe"
$UserConfig = Join-Path $UserHome ".codex\config.toml"

if ($Scope -eq "project") {
  $TargetConfig = Join-Path $ProjectRoot ".codex\config.toml"
}
else {
  $TargetConfig = $UserConfig
}

if (-not (Test-Path -LiteralPath $UserConfig -PathType Leaf)) {
  throw "Missing user Codex config: $UserConfig`nRun .\scripts\bootstrap-codex-plugin.ps1 first."
}

$UserConfigText = Read-TextIfExists $UserConfig
$MarketplacePattern = "(?ms)^\[marketplaces\.$([regex]::Escape($MarketplaceName))\]\r?\n.*?^source = ""(.*?)""$"
$MarketplaceMatch = [regex]::Match($UserConfigText, $MarketplacePattern)
$MarketplaceSource = if ($MarketplaceMatch.Success) { $MarketplaceMatch.Groups[1].Value } else { "" }
$NormalizedMarketplaceSource = $MarketplaceSource
if ($MarketplaceSource -and (Test-Path -LiteralPath $MarketplaceSource)) {
  $NormalizedMarketplaceSource = (Resolve-Path -LiteralPath $MarketplaceSource).Path
}
if (-not [string]::Equals($NormalizedMarketplaceSource, $Root, [System.StringComparison]::OrdinalIgnoreCase)) {
  Write-Error @"
Codex marketplace '$MarketplaceName' does not point at this repo.
Configured source:
  $(if ($MarketplaceSource) { $MarketplaceSource } else { "<missing>" })
Expected source:
  $Root
Run .\scripts\bootstrap-codex-plugin.ps1 with a clean Codex home or remove the conflicting marketplace first.
"@
  exit 1
}

if (-not (Test-Path -LiteralPath $TargetConfig -PathType Leaf)) {
  throw "Missing Codex config for scope '$Scope': $TargetConfig`nRun .\scripts\bootstrap-codex-plugin.ps1 -Scope $Scope first."
}

$TargetText = Read-TextIfExists $TargetConfig
if (-not $TargetText.Contains("[plugins.""$PluginKey""]")) {
  throw "Missing plugin enable block in: $TargetConfig`nRun .\scripts\bootstrap-codex-plugin.ps1 -Scope $Scope first."
}

$Codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $Codex) {
  throw "codex binary not found in PATH"
}

New-Item -ItemType Directory -Force -Path $ProbeDir | Out-Null
$RunDir = if ($Scope -eq "project") { $ProjectRoot } else { $ProbeDir }

$OutputText = Invoke-WithCodexHome $UserHome {
  $Output = & $Codex.Source -C $RunDir debug prompt-input '@wiki test' 2>&1
  $Text = ($Output | Out-String)
  if ($LASTEXITCODE -ne 0) {
    throw "codex debug prompt-input failed with exit code $LASTEXITCODE`n$Text"
  }
  $Text
}

if ($OutputText.Contains("wiki:wiki") -and (Test-TextContainsPath $OutputText $ExpectedSkillPath)) {
  Write-Host "OK: Codex resolves @wiki from this repo."
  Write-Host "Skill path:"
  Write-Host "  $ExpectedSkillPath"
  exit 0
}

$ActualMatch = [regex]::Match($OutputText, '([A-Za-z]:\\[^\r\n"]*skills\\wiki\\SKILL\.md|/[^\r\n"]*skills/wiki/SKILL\.md)')
if ($ActualMatch.Success) {
  Write-Error @"
FAIL: Codex resolved @wiki, but not from this repo.
Resolved skill path:
  $($ActualMatch.Groups[1].Value)
Expected skill path:
  $ExpectedSkillPath
This usually means another Codex home already owns the 'llm-wiki' marketplace.
"@
  exit 1
}

Write-Error @"
PENDING: Codex did not expose @wiki in this headless session.
The marketplace and config are present, but Codex may still require the interactive /plugins UI to materialize or enable the local plugin on first install.

Next step:
  1. Start Codex with HOME set to this Codex home if non-default.
  2. Open /plugins and enable 'LLM Wiki'.
  3. Restart Codex if needed, then rerun this verify script.

Expected skill path once active:
  $ExpectedSkillPath
"@
exit 2
