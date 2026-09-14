$path = 'lib/widgets/scifi_animations.dart'
$text = Get-Content $path -Raw
$text = $text -replace "\r\n", "\n"
$lines = $text -split "\n"
$pattern = 'class (_[A-Za-z0-9]+Painter) extends CustomPainter'
$i = 0
$patched = @()
while ($i -lt $lines.Count) {
    $line = $lines[$i]
    if ($line -match $pattern) {
        $cls = $matches[1]
        $brace = 0
        $end = -1
        for ($j = $i; $j -lt $lines.Count; $j++) {
            $brace += ($lines[$j] -split '{').Count - 1 - (($lines[$j] -split '}').Count - 1)
            if ($brace -eq 0 -and $j -gt $i) {
                $end = $j
                break
            }
        }
        if ($end -eq -1) {
            Write-Error "Could not find end for $cls"
            break
        }
        $classText = ($lines[$i..$end] -join "\n")
        if (-not ($classText -match 'shouldRepaint\(')) {
            $insert = @('  @override', "  bool shouldRepaint(covariant $cls old) => true;", '')
            $lines = $lines[0..($end-1)] + $insert + $lines[$end..($lines.Count-1)]
            $patched += $cls
            $i = $end + $insert.Count
        } else {
            $i = $end + 1
        }
    } else {
        $i++
    }
}
Set-Content -Path $path -Value ($lines -join "`r`n") -Encoding utf8
if ($patched.Count -gt 0) {
    Write-Host "Inserted shouldRepaint for: $($patched -join ', ')"
} else {
    Write-Host 'No changes needed'
}
