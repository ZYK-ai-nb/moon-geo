$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$metadata = Get-Content -LiteralPath (Join-Path $projectRoot 'moon.mod') -Raw
$failed = $false
if ($metadata -match '(?m)^name\s*=\s*"OWNER/') {
    Write-Output 'UNBOUND: module account is intentionally unset.'
    $failed = $true
}
if (Test-Path -LiteralPath (Join-Path $projectRoot '.git')) {
    $authors = @(& git -C $projectRoot log '--format=%an <%ae>' 2>$null | Sort-Object -Unique)
    if ($authors.Count -gt 1) {
        Write-Output 'Multiple commit identities: review the actual contribution record.'
        $failed = $true
    }
} else {
    Write-Output 'No local git history; author identity has not been selected.'
}
if ($failed) { exit 1 }
Write-Output 'Identity metadata check passed.'
