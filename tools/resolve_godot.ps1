$script:ProjectRoot = Split-Path -Parent $PSScriptRoot

function Resolve-Godot {
    [CmdletBinding()]
    param(
        [string]$RequestedPath = "",
        [switch]$Console
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        $explicitPath = $RequestedPath
        if (Test-Path -LiteralPath $explicitPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $explicitPath).Path
        }
        $command = Get-Command -Name $explicitPath -ErrorAction SilentlyContinue
        if ($command -and $command.Source) {
            return $command.Source
        }
        throw "Godot '$explicitPath' nao foi encontrado. Corrija -Godot ou a variavel de ambiente GODOT."
    }

    $executable = if ($Console) {
        "Godot_v4.7.2-stable_win64_console.exe"
    } else {
        "Godot_v4.7.2-stable_win64.exe"
    }
    $projectExecutable = Join-Path $script:ProjectRoot $executable
    if (Test-Path -LiteralPath $projectExecutable -PathType Leaf) {
        return $projectExecutable
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GODOT)) {
        $command = Get-Command -Name $env:GODOT -ErrorAction SilentlyContinue
        if ($command -and $command.Source) {
            return $command.Source
        }
        throw "Godot '$env:GODOT' nao foi encontrado. Corrija a variavel de ambiente GODOT."
    }

    $command = Get-Command -Name "godot" -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        return $command.Source
    }

    throw "Godot nao foi encontrado. Adicione a versao 4.7.2 na raiz do projeto ou configure GODOT/PATH."
}
