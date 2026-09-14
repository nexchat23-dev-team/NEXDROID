param(
  [int]$startLine,
  [int]$count
)
$path = 'lib/widgets/scifi_animations.dart'
$lines = Get-Content $path
for ($i = $startLine - 1; $i -lt $startLine - 1 + $count -and $i -lt $lines.Count; $i++) {
  $line = $lines[$i]
  $hex = -join ($line.ToCharArray() | ForEach-Object { [int]$_ | ForEach-Object { $_.ToString('X4') } })
  Write-Host ('{0,5}: {1}' -f ($i + 1), $line)
  Write-Host ('      HEX: {0}' -f $hex)
}
