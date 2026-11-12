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

# SIG # Begin signature block
# MIIFiQYJKoZIhvcNAQcCoIIFejCCBXYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD7+B/++gUbXWLv
# TtszlYV9QkXWQiIBQmZJg35duL2e9KCCAwIwggL+MIIB5qADAgECAhAuRltqokW4
# qkihDa1YgbfcMA0GCSqGSIb3DQEBCwUAMBcxFTATBgNVBAMMDEdvZG90RGV2Q2Vy
# dDAeFw0yNjExMTIwODAzMjhaFw0yNzExMTIwODIzMjhaMBcxFTATBgNVBAMMDEdv
# ZG90RGV2Q2VydDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALvAWL2t
# J84wYxZalmkdWosjGrUp1MqP4LViwo3sUul2W98cUbjmnE98JCBTLdGqD2g3yf0v
# QQ86p5oWVGBFPJa+MLphzPDIWdIdQuWbKY+kikVYjtEXdX0YkwMfsmucj6LsXm9t
# E7yy4NGGqIg0tdVWtKCXL/Ba9x7o0Vvka2CnIzMVvvmk6giNgVvZ3DTYhsAiX1jD
# z+ScrmiysX4LliEFzJ4BmBxvc+k/pwAzpzuL+eYZaeOv65UzbeNK0dMx8D7p+WP/
# PYwjpyIfmiqibsvceA6ysnma31n/xkFtpL+iFEJ6Mlnzpj3NHKqJFpK9J0yC9Ss0
# NVy+2hESZZBSJHECAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMB0GA1UdDgQWBBSfEhPoi0B/BqloBg62wnZ62xjvPTANBgkqhkiG
# 9w0BAQsFAAOCAQEAVjXMEP3Sfb14Ha8OwNbXogeMZpiJxPEjS3mZNR98vKocnLxd
# CrH8jfBi4RB56lc06nNtKdduB4nPiSZ5qeHA3iz9kTkR+ipcQpmsUjhjKFZuH8Nd
# nR1JMmGLrIUNk9WExQuO/lL19pYb2wfWVjNO5Colbt0kcJw9OYWP4Z1I8ZTJvIS8
# Ls0CWE3BYZtmzYPiYzVs2c7l489VlrM0wlapSiPrsN2g3QY7vIJ645bguefOppOP
# 3OJMrnrdEXmEA1gTAqkAGitXx3Yl1MCScBa/fTvgz6Ci2aqSlZjKfEYYjuq5MUm9
# Vstm8cs8ubWT/Ifq1t6UDrjvFz2wN0pkaI6EFjGCAd0wggHZAgEBMCswFzEVMBMG
# A1UEAwwMR29kb3REZXZDZXJ0AhAuRltqokW4qkihDa1YgbfcMA0GCWCGSAFlAwQC
# AQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwG
# CisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZI
# hvcNAQkEMSIEIKFzDwhKfHJC9NEoqS6SPlj1eO15QuSSWPut7zhDKtTPMA0GCSqG
# SIb3DQEBAQUABIIBAELfhCJ0hPD0m9UtVoPKAnSISPHrDMH0fUZYG9ZXNBpWH9wX
# GoFCpKFXZpLkhq+x69DbuUH5PDOgDz2YuisRuxdpbGLKZxPsxp1tjHR0ETsQ0jhT
# woOBSBzSbiEIhRrnp8QW/iCC80CTWomEQvmdVgRT5u1sF6/pGu6esuQtdv1m5t9x
# 1D68+RW6zSXiTB1Keh4ZH1OPD8SlqFF4hPwLIZmJPplKRzy1R8R7+sVx0m6x9Fj6
# h4tHU++D2OqXbQ4D/42mhdd1aLFBe1wVy1cw9lqR2Fmc4niRhP3Z81vrK4EE6Q9q
# lwm8/evK1Gt47OZottEKJ+NJFvm7tCOSVBovxO0=
# SIG # End signature block
