# Roda os testes automatizados no Windows.
# Uso: powershell -ExecutionPolicy Bypass -File tools/test.ps1 [-Godot caminho\godot.exe] [-Filter parte_do_nome]
param([string]$Godot = "", [string]$Filter = "")
Set-Location (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "resolve_godot.ps1")
$godotPath = Resolve-Godot -RequestedPath $Godot -Console

if ($Filter -ne "") { $env:TEST_FILTER = $Filter }
$importOutput = & $godotPath --headless --import 2>&1 | Out-String
$importExitCode = $LASTEXITCODE
if ($importExitCode -ne 0) {
    Write-Output $importOutput
    Write-Error "A importacao do projeto falhou (codigo $importExitCode)."
    exit $importExitCode
}

$out = & $godotPath --path . --audio-driver Dummy --script res://tests/run_tests.gd 2>&1 | Out-String
$testExitCode = $LASTEXITCODE
Write-Output $out
if ($out -match "SCRIPT ERROR|Parse Error|ERROR:") {
    Write-Error "Erro de script detectado durante os testes."
    exit 1
}
if ($out -notmatch "(\d+) testes, (\d+) verificacoes, (\d+) falhas") {
    Write-Error "O executor de testes nao produziu um resumo reconhecivel."
    exit 1
}
if ([int]$Matches[1] -eq 0) {
    Write-Error "Nenhum teste foi executado. Confira o filtro '$Filter'."
    exit 1
}
if ($testExitCode -ne 0) { exit $testExitCode }
if ([int]$Matches[3] -gt 0) { exit 1 }
