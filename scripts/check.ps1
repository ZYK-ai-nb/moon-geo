param([switch]$IncludeNative)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    $logDir = Join-Path $projectRoot 'work\validation'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $checks = @(
        @{ Name='version'; Program='moon'; Arguments=@('version','--all') },
        @{ Name='oracle'; Program='python'; Arguments=@('scripts/generate_oracle.py','--check') },
        @{ Name='check-all'; Program='moon'; Arguments=@('check','--target','all','--deny-warn') },
        @{ Name='format'; Program='moon'; Arguments=@('fmt','--check') },
        @{ Name='interface'; Program='moon'; Arguments=@('info') }
    )
    foreach ($backend in @('wasm','wasm-gc','js')) {
        $checks += @{ Name="build-$backend"; Program='moon'; Arguments=@('build','--target',$backend,'--deny-warn') }
        $checks += @{ Name="test-$backend"; Program='moon'; Arguments=@('test','--target',$backend,'--deny-warn') }
    }
    if ($IncludeNative) {
        $checks += @{ Name='test-native'; Program='moon'; Arguments=@('test','--target','native','--deny-warn') }
    }
    foreach ($example in @('cmd/main','examples/predicates','examples/regions','examples/dynamic_index')) {
        $checks += @{ Name=('run-' + $example.Replace('/','-')); Program='moon'; Arguments=@('run',$example,'--target','js') }
    }
    $results = @()
    foreach ($check in $checks) {
        $program = $check.Program
        $arguments = $check.Arguments
        Write-Output ('> ' + $program + ' ' + ($arguments -join ' '))
        Get-Command $program -ErrorAction Stop | Out-Null
        $savedErrorPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = & $program @arguments 2>&1 | ForEach-Object { $_.ToString() }
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $savedErrorPreference
        }
        $output | Out-File -LiteralPath (Join-Path $logDir ($check.Name + '.log')) -Encoding utf8
        $output | Write-Output
        $results += [pscustomobject]@{ check=$check.Name; command=($program + ' ' + ($arguments -join ' ')); exit_code=$exitCode }
        if ($exitCode -ne 0) {
            $results | ConvertTo-Json | Out-File -LiteralPath (Join-Path $logDir 'results.json') -Encoding utf8
            throw "Check failed: $($check.Name) (exit $exitCode)"
        }
    }
    $results | ConvertTo-Json | Out-File -LiteralPath (Join-Path $logDir 'results.json') -Encoding utf8
    if (-not $IncludeNative) { Write-Output 'Native runtime was not requested; add -IncludeNative on a machine with the required compiler.' }
} finally {
    Pop-Location
}
