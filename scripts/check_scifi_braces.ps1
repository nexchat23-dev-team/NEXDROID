$path = 'lib/widgets/scifi_animations.dart'
$lines = Get-Content $path
$brace = 0
for ($i = 0; $i -lt $lines.Length; $i++) {
  $line = $lines[$i]
  $brace += ($line -split '{').Count - 1
  $brace -= ($line -split '}').Count - 1
  if ($line -match '^class ') {
    Write-Host "Line $($i + 1): class detected: $line"
  }
  if ($brace -lt 0) { Write-Host "Line $($i + 1): brace underflow at '$line'"; $brace = 0 }
}
Write-Host "Final brace count: $brace"
