# A two-line Claude Code statusline (Catppuccin Macchiato).
# Windows version of statusline.sh with the same output and no jq needed; keep the two in sync.
# ASCII-only because Windows PowerShell 5.1 misreads UTF-8 files without a BOM,
# so the glyphs are [char] codes.

$esc = [char]27
$used = [string][char]0x2501; $left = [string][char]0x2500  # bar pieces
$dot = [char]0xB7; $arrow = [char]0x21BB                    # separator, reset arrow

try {
  $j = [IO.StreamReader]::new([Console]::OpenStandardInput(), [Text.Encoding]::UTF8).ReadToEnd() | ConvertFrom-Json
} catch { $j = $null }

# Catppuccin Macchiato as 24-bit ANSI colors (1 = bold, 2 = dim).
$mauve = '38;2;198;160;246'; $yellow = '38;2;238;212;159'; $peach = '1;38;2;245;169;127'
$blue = '38;2;138;173;244'; $green = '38;2;166;218;149'; $red = '38;2;237;135;150'; $dim = '2;38;2;202;211;245'

# c <style> <text>: text in an ANSI style, then reset.
function c($style, $text) { "$esc[${style}m$text$esc[0m" }

# pct <value>: whole-number percentage, rounded half away from zero like jq's round.
function pct($v) { [int][Math]::Round([double]$v, [MidpointRounding]::AwayFromZero) }

# meter <label> <percent> <width> <style>: label, bar and percentage.
# Turns yellow from 50% and red from 80%.
function meter($label, $pct, $width, $style) {
  $filled = [Math]::Max(0, [Math]::Min($width, [Math]::Floor(($pct * $width + 50) / 100)))
  if ($pct -ge 80) { $style = $red } elseif ($pct -ge 50) { $style = $yellow }
  c $style ("$label " + $used * $filled + $left * ($width - $filled) + " $pct%")
}

# limit <label> <window>: separator, meter and time until reset, or nothing without data.
function limit($label, $w) {
  if ($null -eq $w.used_percentage) { return }
  $out = (c $dim " $dot ") + (meter $label (pct $w.used_percentage) 10 $green)
  $secs = [Math]::Floor($w.resets_at - $now)
  if ($secs -ge 86400) { $out += c $dim (" $arrow {0}d{1}h" -f [Math]::Floor($secs / 86400), [Math]::Floor($secs % 86400 / 3600)) }
  elseif ($secs -ge 3600) { $out += c $dim (" $arrow {0}h{1}m" -f [Math]::Floor($secs / 3600), [Math]::Floor($secs % 3600 / 60)) }
  elseif ($secs -gt 0) { $out += c $dim (" $arrow {0}m" -f [Math]::Floor($secs / 60)) }
  $out
}

$now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000
$dir = [string]$j.workspace.current_dir
$branch = if ($dir -and (Get-Command git -ErrorAction SilentlyContinue)) { git -C $dir rev-parse --abbrev-ref HEAD 2>$null }
$effort = if ($j.thinking.enabled -eq $true) { $j.effort.level }

# Line 1: [folder]:branch . Model / effort
$out = c $mauve "[$($dir -replace '.*[\\/]')]"
if ($branch) { $out += c $yellow ":$branch" }
$out += (c $dim " $dot ") + (c $peach $j.model.display_name)
if ($effort) { $out += c $dim " / $effort" }

# Line 2: context window . 5-hour limit . 7-day limit
$out += "`n" + (meter 'ctx' (pct $j.context_window.used_percentage) 20 $blue)
$out += limit '5h' $j.rate_limits.five_hour
$out += limit '7d' $j.rate_limits.seven_day

# Write UTF-8 bytes directly so the console code page can't mangle the glyphs.
$bytes = [Text.Encoding]::UTF8.GetBytes($out)
[Console]::OpenStandardOutput().Write($bytes, 0, $bytes.Length)
