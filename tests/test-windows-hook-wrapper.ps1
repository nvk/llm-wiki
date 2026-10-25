# Native regression test for the Windows hook wrapper (scripts/llm-wiki-hook.cmd).
#
# A plugin installed under a path containing "!" and spaces must still reach the
# session helper, and the helper's exit code must survive the wrapper.
#
# Run on Windows:
#   powershell -ExecutionPolicy Bypass -File tests/test-windows-hook-wrapper.ps1

$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    Write-Host 'SKIP: Windows only'
    exit 0
}

$repo = Split-Path -Parent $PSScriptRoot
$wrapper = Join-Path $repo 'scripts/llm-wiki-hook.cmd'
if (-not (Test-Path $wrapper)) {
    throw "missing wrapper: $wrapper"
}

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("llm-wiki-hook-! with spaces-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $installed = Join-Path $fixture 'llm-wiki-hook.cmd'
    Copy-Item $wrapper $installed

    $helper = @'
import sys
print("WRAPPER_OK")
sys.exit(int(sys.argv[1]) if len(sys.argv) > 1 else 0)
'@
    $helperPath = Join-Path $fixture 'llm_wiki_session.py'
    [System.IO.File]::WriteAllText($helperPath, $helper, (New-Object System.Text.UTF8Encoding($false)))

    $seven = & cmd.exe /d /s /c "`"$installed`" 7" 2>&1
    if ($LASTEXITCODE -ne 7) {
        throw "exit code $LASTEXITCODE, expected 7; output: $seven"
    }
    if (($seven -join "`n") -notmatch 'WRAPPER_OK') {
        throw "helper did not run; output: $seven"
    }

    $zero = & cmd.exe /d /s /c "`"$installed`" 0" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "exit code $LASTEXITCODE, expected 0; output: $zero"
    }
    if (($zero -join "`n") -notmatch 'WRAPPER_OK') {
        throw "helper did not run; output: $zero"
    }

    Write-Host 'PASS: wrapper survives "!" and spaces in its path and returns the helper exit code'
}
finally {
    Remove-Item -Recurse -Force $fixture -ErrorAction SilentlyContinue
}
