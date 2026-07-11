param(
  [ValidateSet("project", "user")]
  [string]$Scope = "user",
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

Verify that Codex resolves the @wiki plugin and installs the explicit-only
`$wiki-query skill from this repo.

Options:
  -Scope user           Verify the supported user install (default: user)
  -ProjectRoot <dir>    Working directory for the prompt probe (default: current dir)
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

function Invoke-WithCodexHome([string]$UserHomeValue, [scriptblock]$Body) {
  $oldHome = $env:HOME
  $oldUserProfile = $env:USERPROFILE
  $codexHome = Join-Path $UserHomeValue ".codex"
  try {
    $env:HOME = $UserHomeValue
    if ($IsWindowsHost) {
      $env:USERPROFILE = $UserHomeValue
    }
    & { $env:CODEX_HOME = $codexHome; & $Body }
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
  # Remove Windows extended-length prefix \\?\ for comparison
  if ($PathValue.StartsWith("\\?\")) {
    $PathValue = [System.Uri]::UnescapeDataString($PathValue.Substring(4))
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

function Get-AllStrings($Value) {
  if ($null -eq $Value) {
    return
  }
  if ($Value -is [string]) {
    Write-Output $Value
    return
  }
  if ($Value -is [System.Collections.IDictionary]) {
    foreach ($Item in $Value.Values) {
      Get-AllStrings $Item
    }
    return
  }
  if ($Value -is [System.Collections.IEnumerable]) {
    foreach ($Item in $Value) {
      Get-AllStrings $Item
    }
    return
  }
  if ($Value -is [psobject]) {
    foreach ($Property in $Value.PSObject.Properties) {
      Get-AllStrings $Property.Value
    }
  }
}

if ($Help) {
  Show-Usage
  exit 0
}

if ($Scope -eq "project") {
  throw "Project-scoped plugin enablement is not supported by Codex 0.144. Verify the user-scoped install with -Scope user."
}

$Root = Resolve-ExistingDirectory (Join-Path $PSScriptRoot "..")
$ProjectRoot = Resolve-ExistingDirectory $ProjectRoot
$UserHome = Resolve-ExistingDirectory $UserHome
$MarketplaceName = "llm-wiki"
$PluginKey = "wiki@$MarketplaceName"
$SourcePluginRoot = Join-Path $Root "plugins\llm-wiki"
$SourceSkillPath = Join-Path $SourcePluginRoot "skills\wiki\SKILL.md"
$SourceQuerySkillPath = Join-Path $SourcePluginRoot "skills\wiki-query\SKILL.md"
$ManifestPath = Join-Path $SourcePluginRoot ".codex-plugin\plugin.json"
$Manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$ExpectedVersion = [string]$Manifest.version
$UserConfig = Join-Path $UserHome ".codex\config.toml"

if (-not (Test-Path -LiteralPath $UserConfig -PathType Leaf)) {
  throw "Missing user Codex config: $UserConfig`nRun .\scripts\bootstrap-codex-plugin.ps1 first."
}

$UserConfigText = [System.IO.File]::ReadAllText($UserConfig, [System.Text.Encoding]::UTF8)
if (-not $UserConfigText.Contains("[plugins.`"$PluginKey`"]")) {
  throw "Missing plugin enable block in: $UserConfig`nRun .\scripts\bootstrap-codex-plugin.ps1 -Scope user first."
}

$Codex = Get-Command codex -ErrorAction SilentlyContinue
if (-not $Codex) {
  throw "codex binary not found in PATH"
}

$ListData = Invoke-WithCodexHome $UserHome {
  Invoke-CodexJson $Codex @("-C", $ProjectRoot, "plugin", "list", "--marketplace", $MarketplaceName, "--json")
}
$Plugin = @($ListData.installed) |
  Where-Object { $_.pluginId -eq $PluginKey } |
  Select-Object -First 1
if ($null -eq $Plugin) {
  throw "FAIL: $PluginKey is not installed"
}

$Errors = @()
if (-not $Plugin.installed) {
  $Errors += "plugin is not installed"
}
if (-not $Plugin.enabled) {
  $Errors += "plugin is not enabled in the selected scope"
}
if ([string]$Plugin.version -ne $ExpectedVersion) {
  $Errors += "installed version '$($Plugin.version)' != expected '$ExpectedVersion'"
}
if (-not (Test-SamePath ([string]$Plugin.source.path) $SourcePluginRoot)) {
  $Errors += "plugin source does not point at $SourcePluginRoot"
}

$MarketplaceSource = Normalize-PathForComparison ([string]$Plugin.marketplaceSource.source)
if (-not (Test-SamePath $MarketplaceSource $Root)) {
  $Errors += "marketplace source does not point at $Root"
}
if ($Errors.Count -gt 0) {
  throw "FAIL: $($Errors -join '; ')"
}

$ExpectedCacheRoot = Join-Path $UserHome ".codex\plugins\cache\$MarketplaceName\wiki\$ExpectedVersion"
$ExpectedCacheSkill = Join-Path $ExpectedCacheRoot "skills\wiki\SKILL.md"
$ExpectedCacheQuerySkill = Join-Path $ExpectedCacheRoot "skills\wiki-query\SKILL.md"
if (-not (Test-Path -LiteralPath $ExpectedCacheSkill -PathType Leaf)) {
  throw "FAIL: installed Codex cache is missing the wiki skill: $ExpectedCacheSkill"
}
if (-not (Test-Path -LiteralPath $ExpectedCacheQuerySkill -PathType Leaf)) {
  throw "FAIL: installed Codex cache is missing the wiki-query skill: $ExpectedCacheQuerySkill"
}

$PromptData = Invoke-WithCodexHome $UserHome {
  Invoke-CodexJson $Codex @("-C", $ProjectRoot, "debug", "prompt-input", "@wiki test")
}
$PromptStrings = @(Get-AllStrings $PromptData)
$ActualSkillPath = ""
foreach ($Text in $PromptStrings) {
  foreach ($Line in ($Text -split "`r?`n")) {
    if (-not $Line.Contains("- wiki:wiki:")) {
      continue
    }
    $Match = [regex]::Match($Line, '\(file:\s+(.+?[\\/]skills[\\/]wiki[\\/]SKILL\.md)\)')
    if ($Match.Success) {
      $ActualSkillPath = $Match.Groups[1].Value
      break
    }
  }
  if ($ActualSkillPath) {
    break
  }
}

if (-not $ActualSkillPath) {
  throw "FAIL: Codex did not expose wiki:wiki in the headless prompt. Run .\scripts\bootstrap-codex-plugin.ps1 -Scope user again."
}
if (-not ((Test-SamePath $ActualSkillPath $ExpectedCacheSkill) -or (Test-SamePath $ActualSkillPath $SourceSkillPath))) {
  throw "FAIL: Codex resolved wiki:wiki from an unexpected plugin: $ActualSkillPath`nExpected: $ExpectedCacheSkill"
}

$CachedQuery = [System.IO.File]::ReadAllText($ExpectedCacheQuerySkill, [System.Text.Encoding]::UTF8)
$SourceQuery = [System.IO.File]::ReadAllText($SourceQuerySkillPath, [System.Text.Encoding]::UTF8)
if ($CachedQuery -ne $SourceQuery) {
  throw "FAIL: cached wiki-query skill differs from the generated source: $ExpectedCacheQuerySkill"
}

$PromptText = $PromptStrings -join "`n"
if ($PromptText -match '[\\/]skills[\\/]wiki-query[\\/]SKILL\.md') {
  throw "FAIL: explicit-only wiki-query leaked into the implicit skill list."
}

Write-Host "OK: Codex resolves @wiki and installs explicit-only `$wiki-query from $PluginKey version $ExpectedVersion."
Write-Host "Skill paths:"
Write-Host "  $ActualSkillPath"
Write-Host "  $ExpectedCacheQuerySkill"
