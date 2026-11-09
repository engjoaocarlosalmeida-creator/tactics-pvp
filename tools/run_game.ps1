# Abre o jogo no Windows. Opcoes do jogo apos "--" (veja o topo de src/view/game_view.gd).
param([string]$Godot = "", [string[]]$GameArgs = @(), [switch]$Demo)
Set-Location (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "resolve_godot.ps1")
$godotPath = Resolve-Godot -RequestedPath $Godot

if ($Demo) {
    $GameArgs = @("--mode=demo", "--seed=7", "--fast") + $GameArgs
}
$arguments = @("--path", ".", "--") + $GameArgs
& $godotPath @arguments
exit $LASTEXITCODE
