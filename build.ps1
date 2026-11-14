param(
    [Parameter(Mandatory = $true)][string]$GodotConsole,
    [string]$GodotBinary
)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
if (-not $GodotBinary) {
    $GodotBinary = $GodotConsole.Replace('_console.exe', '.exe')
}
if (-not (Test-Path -LiteralPath $GodotConsole)) { throw 'Godot-Konsole nicht gefunden.' }
if (-not (Test-Path -LiteralPath $GodotBinary)) { throw 'Godot-Binary nicht gefunden.' }
$oldAppData = $env:APPDATA
function Invoke-Godot([string[]]$EngineArguments, [string]$LogFile) {
    # Windows PowerShell wraps native stderr as error records even when the
    # engine exits successfully. Judge by exit code and script-error output.
    $ErrorActionPreference = 'Continue'
    & $GodotConsole @EngineArguments *> $LogFile
    $engineExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($engineExit -ne 0 -or (Select-String -LiteralPath $LogFile -Pattern 'SCRIPT ERROR|Parse Error' -Quiet)) {
        throw "Godot fehlgeschlagen, siehe $LogFile."
    }
}
try {
    $env:APPDATA = Join-Path $projectRoot '.runtime'
    $buildDir = Join-Path $projectRoot 'build'
    $distDir = Join-Path $projectRoot 'dist'
    $windowsDir = Join-Path $distDir 'Mooswinkel-Windows'
    New-Item -ItemType Directory -Path $buildDir,$distDir,$windowsDir,$env:APPDATA -Force | Out-Null
    Invoke-Godot -EngineArguments @('--headless','--path',$projectRoot,'--editor','--import','--quit') -LogFile (Join-Path $buildDir 'import.log')
    foreach ($test in @('suite','expansion','residents_test','endless_test','phase2_test','campaign','runtime','licenses')) {
        Invoke-Godot -EngineArguments @('--headless','--path',$projectRoot,'--script',"res://tests/$test.gd") -LogFile (Join-Path $buildDir "$test.log")
    }
    Invoke-Godot -EngineArguments @('--headless','--path',$projectRoot,'--export-pack','Windows Desktop',(Join-Path $buildDir 'Mooswinkel.pck')) -LogFile (Join-Path $buildDir 'export.log')
    Copy-Item -LiteralPath $GodotBinary -Destination (Join-Path $windowsDir 'Mooswinkel.exe') -Force
    Copy-Item -LiteralPath (Join-Path $buildDir 'Mooswinkel.pck') -Destination $windowsDir -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $windowsDir -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/GODOT-LICENSE.txt'),(Join-Path $projectRoot 'docs/GODOT-THIRD-PARTY.json') -Destination $windowsDir -Force
    @'
@echo off
start "" "%~dp0Mooswinkel.exe" --main-pack "%~dp0Mooswinkel.pck"
'@ | Set-Content -LiteralPath (Join-Path $windowsDir 'Start-Mooswinkel.cmd') -Encoding Ascii
    Compress-Archive -Path (Join-Path $windowsDir '*') -DestinationPath (Join-Path $distDir 'Mooswinkel-Windows.zip') -Force
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $sourceZip = Join-Path $distDir 'Mooswinkel-Quellprojekt.zip'
    $stream = [IO.File]::Open($sourceZip, [IO.FileMode]::Create)
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -LiteralPath $projectRoot -File -Recurse | ForEach-Object {
            $relative = $_.FullName.Substring($projectRoot.Length + 1).Replace('\','/')
            if ($relative -notmatch '^(\.godot|\.runtime[^/]*|build|dist|archive)/' -and $relative -notmatch '\.import$') {
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, "Mooswinkel/$relative", [IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        }
    }
    finally { $archive.Dispose(); $stream.Dispose() }
    Get-FileHash -LiteralPath $sourceZip,(Join-Path $distDir 'Mooswinkel-Windows.zip') | Format-Table Hash,Path -AutoSize
}
finally { $env:APPDATA = $oldAppData }


