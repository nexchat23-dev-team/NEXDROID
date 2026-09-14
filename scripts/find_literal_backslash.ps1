$path = 'lib/widgets/scifi_animations.dart'
$lines = Get-Content $path
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '\\\\') {
    Write-Host ($i + 1) ':' $lines[$i]
  }
}
