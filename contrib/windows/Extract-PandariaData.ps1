param(
    [Parameter(Mandatory = $true)]
    [string]$ClientDir,

    [string]$ServerDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\server')).Path,

    [int]$Threads = 2,

    [string]$Locale = ''
)

$ErrorActionPreference = 'Stop'

$clientPath = (Resolve-Path $ClientDir).Path
$serverPath = (Resolve-Path $ServerDir).Path
$dataPath = Join-Path $serverPath 'Data'

foreach ($tool in @('mapextractor.exe', 'vmap4extractor.exe', 'vmap4assembler.exe', 'mmaps_generator.exe')) {
    $source = Join-Path $serverPath $tool
    if (-not (Test-Path $source)) {
        throw "$tool was not found in $serverPath. Build and install the extraction tools first."
    }
    Copy-Item -LiteralPath $source -Destination (Join-Path $clientPath $tool) -Force
}

New-Item -ItemType Directory -Force -Path $dataPath | Out-Null

$mapArgs = @('-i', $clientPath, '-o', $dataPath)
if ($Locale) {
    $mapArgs += @('-l', $Locale)
}

Write-Host 'Extracting maps, dbc/db2, cameras, and gt...'
& (Join-Path $clientPath 'mapextractor.exe') @mapArgs
if ($LASTEXITCODE -ne 0) { throw 'mapextractor failed.' }

Write-Host 'Extracting raw vmaps Buildings data...'
Push-Location $clientPath
try {
    & '.\vmap4extractor.exe'
    if ($LASTEXITCODE -ne 0) { throw 'vmap4extractor failed.' }

    Write-Host 'Assembling vmaps...'
    & '.\vmap4assembler.exe' 'Buildings' (Join-Path $dataPath 'vmaps') '--threads' $Threads
    if ($LASTEXITCODE -ne 0) { throw 'vmap4assembler failed.' }
}
finally {
    Pop-Location
}

Write-Host "Generating mmaps with $Threads thread(s). This is the long CPU-heavy step."
& (Join-Path $clientPath 'mmaps_generator.exe') '--input' $dataPath '--output' $dataPath '--threads' $Threads
if ($LASTEXITCODE -ne 0) { throw 'mmaps_generator failed.' }

Write-Host ''
Write-Host "Extraction complete. worldserver.conf can stay at DataDir = `"Data`"."
