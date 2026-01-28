# Check for non-ASCII quote characters
$content = Get-Content ".\scripts\Script0.ps1" -Raw

# Check for smart quotes (curly quotes)
$leftDouble = [char]0x201C  # "
$rightDouble = [char]0x201D  # "
$leftSingle = [char]0x2018  # '
$rightSingle = [char]0x2019  # '

$issues = @()

if ($content.Contains($leftDouble)) {
    $issues += "Left double curly quote found (U+201C)"
}
if ($content.Contains($rightDouble)) {
    $issues += "Right double curly quote found (U+201D)"
}
if ($content.Contains($leftSingle)) {
    $issues += "Left single curly quote found (U+2018)"
}
if ($content.Contains($rightSingle)) {
    $issues += "Right single curly quote found (U+2019)"
}

if ($issues.Count -eq 0) {
    Write-Host "[OK] No smart quotes found" -ForegroundColor Green
} else {
    Write-Host "[!] Smart quotes detected:" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
}

# Count regular quotes
$doubleQuotes = ($content.ToCharArray() | Where-Object { $_ -eq '"' }).Count
Write-Host "Regular double quotes: $doubleQuotes"

# Check if balanced
if ($doubleQuotes % 2 -eq 0) {
    Write-Host "Double quotes are balanced (even count)" -ForegroundColor Green
} else {
    Write-Host "Double quotes are UNBALANCED (odd count)" -ForegroundColor Red
}
