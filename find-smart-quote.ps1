# Find line with smart quote
$lines = Get-Content ".\scripts\Script0.ps1"
$leftDouble = [char]0x201C  # "

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Contains($leftDouble)) {
        Write-Host "Line $($i+1): Smart quote found" -ForegroundColor Red
        Write-Host "  $($lines[$i])" -ForegroundColor Yellow

        # Show the position of the smart quote
        $pos = $lines[$i].IndexOf($leftDouble)
        Write-Host "  Position in line: $pos" -ForegroundColor Cyan
    }
}
