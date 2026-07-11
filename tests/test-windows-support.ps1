param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$HooksJsonPath = Join-Path $ProjectRoot "plugins\llm-wiki\hooks\hooks.json"

function Write-Utf8NoBom([string]$PathValue, [string]$Text) {
  $parent = Split-Path -Parent $PathValue
  if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
  }
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($PathValue, $Text, $encoding)
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) {
    throw $Message
  }
  Write-Host "PASS: $Message"
}

function Restore-Env([string]$Name, [string]$Value) {
  if ($null -eq $Value) {
    Remove-Item -Path "Env:\$Name" -ErrorAction SilentlyContinue
  }
  else {
    Set-Item -Path "Env:\$Name" -Value $Value
  }
}

Write-Host "=== Windows Codex Hook Support ==="

$Hooks = Get-Content -LiteralPath $HooksJsonPath -Raw | ConvertFrom-Json
$ExpectedEvents = @("SessionStart", "UserPromptSubmit", "PostToolUse", "PreCompact", "PostCompact", "Stop")
foreach ($EventName in $ExpectedEvents) {
  $Hook = $Hooks.hooks.$EventName[0].hooks[0]
  Assert-True ($Hook.command -like "*--event-name $EventName*") "$EventName command includes --event-name"
  Assert-True ($Hook.commandWindows -like "*llm-wiki-hook.cmd*") "$EventName has commandWindows wrapper"
  Assert-True ($Hook.commandWindows -like "*--event-name $EventName*") "$EventName commandWindows includes --event-name"
}

# Avoid using the Windows temp directory for test artifacts,
# since Windows refuses to create helper binaries under the directory.
$TempRoot = Join-Path $PSScriptRoot "temp"
$PluginRoot = Join-Path $TempRoot "plugin root"
$HomeRoot = Join-Path $TempRoot "home"
$HubRoot = Join-Path $TempRoot "wiki"

try {
  New-Item -ItemType Directory -Force -Path $PluginRoot, $HomeRoot, $HubRoot | Out-Null
  Copy-Item -Recurse -LiteralPath (Join-Path $ProjectRoot "plugins\llm-wiki\hooks") -Destination $PluginRoot
  Write-Utf8NoBom (Join-Path $HomeRoot ".config\llm-wiki\config.json") ((@{ hub_path = $HubRoot } | ConvertTo-Json -Compress) + "`n")

  $OldPluginRoot = $env:PLUGIN_ROOT
  $OldHome = $env:HOME
  $OldUserProfile = $env:USERPROFILE
  try {
    $env:PLUGIN_ROOT = $PluginRoot
    $env:HOME = $HomeRoot
    $env:USERPROFILE = $HomeRoot

    $PostToolUse = $Hooks.hooks.PostToolUse[0].hooks[0].commandWindows
    $Payload = @{
      session_id = "windows-manifest"
      hook_event_name = "PostToolUse"
      cwd = $ProjectRoot
      tool_name = "PowerShell"
    } | ConvertTo-Json -Compress
    $Payload | & cmd.exe /d /s /c $PostToolUse
    Assert-True ($LASTEXITCODE -eq 0) "commandWindows exits zero for PowerShell-piped JSON"
    Assert-True (Test-Path -LiteralPath (Join-Path $HubRoot ".sessions\state\codex\windows-manifest.json")) "commandWindows writes session state"

    "not json" | & cmd.exe /d /s /c $PostToolUse
    Assert-True ($LASTEXITCODE -eq 0) "commandWindows exits zero for invalid hook JSON"
  }
  finally {
    Restore-Env "PLUGIN_ROOT" $OldPluginRoot
    Restore-Env "HOME" $OldHome
    Restore-Env "USERPROFILE" $OldUserProfile
  }

  $Codex = Get-Command codex -ErrorAction SilentlyContinue
  if ($Codex) {
    $PowerShellExe = (Get-Process -Id $PID).Path
    $BootstrapScript = Join-Path $ProjectRoot "scripts\bootstrap-codex-plugin.ps1"
    $CodexHome = Join-Path $TempRoot "codex home"
    New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null

    & $PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $BootstrapScript `
      -Scope user -ProjectRoot $ProjectRoot -UserHome $CodexHome -Verify
    Assert-True ($LASTEXITCODE -eq 0) "PowerShell bootstrap installs and verifies the Codex plugin in a clean home"

    $Manifest = Get-Content -LiteralPath (Join-Path $ProjectRoot "plugins\llm-wiki\.codex-plugin\plugin.json") -Raw | ConvertFrom-Json
    $CacheRoot = Join-Path $CodexHome ".codex\plugins\cache\llm-wiki\wiki\$($Manifest.version)"
    Assert-True (Test-Path -LiteralPath (Join-Path $CacheRoot "skills\wiki\SKILL.md")) "bootstrap installs the wiki skill cache"
    Assert-True (Test-Path -LiteralPath (Join-Path $CacheRoot "skills\wiki-query\SKILL.md")) "bootstrap installs the explicit wiki-query skill cache"
  }
  else {
    Write-Host "SKIP: codex binary not found; clean-home Windows bootstrap test not run."
  }
}
finally {
  Remove-Item -Recurse -Force -LiteralPath $TempRoot -ErrorAction SilentlyContinue
}

Write-Host "OK: Windows Codex hook support smoke test passed."
