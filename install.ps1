# Installs the statusline on Windows: copies statusline.ps1 into ~/.claude and points
# "statusLine" in ~/.claude/settings.json at it (backing up the old file first).
$ErrorActionPreference = 'Stop'

$url = 'https://raw.githubusercontent.com/v0-3/statusline/main/statusline.ps1'
$dir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$script = Join-Path $dir 'statusline.ps1'
$settings = Join-Path $dir 'settings.json'
New-Item -ItemType Directory -Force -Path $dir | Out-Null

# Run from a clone: install the local copy. Run via `irm | iex`: download it.
if ($PSScriptRoot) { Copy-Item (Join-Path $PSScriptRoot 'statusline.ps1') $script -Force }
else { Invoke-WebRequest $url -OutFile $script -UseBasicParsing }

$config = [pscustomobject]@{}
if (Test-Path $settings) {
  $text = [IO.File]::ReadAllText($settings)
  if ($text.Trim()) {
    Copy-Item $settings "$settings.bak.$([DateTimeOffset]::Now.ToUnixTimeSeconds())"
    $config = $text | ConvertFrom-Json
  }
}
$command = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + ($script -replace '\\', '/') + '"'
$config | Add-Member -Force -NotePropertyName statusLine -NotePropertyValue ([pscustomobject]@{ type = 'command'; command = $command })
[IO.File]::WriteAllText($settings, ($config | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))

Write-Host "Installed $script. Claude Code picks it up automatically."
