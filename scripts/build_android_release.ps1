param(
    [ValidateSet("apk", "appbundle")]
    [string]$Target = "apk"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$localPropertiesPath = Join-Path $projectRoot "android\local.properties"

function Get-LocalPropertyValue {
    param(
        [string]$Path,
        [string]$Key
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    foreach ($line in Get-Content $Path) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("#") -or -not $trimmed.Contains("=")) {
            continue
        }

        $parts = $trimmed.Split("=", 2)
        if ($parts[0].Trim() -eq $Key) {
            return $parts[1].Trim()
        }
    }

    return $null
}

$mapsApiKey =
    Get-LocalPropertyValue -Path $localPropertiesPath -Key "MAPS_API_KEY"

if ([string]::IsNullOrWhiteSpace($mapsApiKey)) {
    $mapsApiKey = $env:DART_MAPS_API_KEY
}

if ([string]::IsNullOrWhiteSpace($mapsApiKey)) {
    $mapsApiKey = $env:GOOGLE_MAPS_API_KEY
}

if ([string]::IsNullOrWhiteSpace($mapsApiKey)) {
    $mapsApiKey = $env:ANDROID_MAPS_API_KEY
}

if ([string]::IsNullOrWhiteSpace($mapsApiKey)) {
    throw "Missing Google Maps API key. Add MAPS_API_KEY to android/local.properties or set DART_MAPS_API_KEY."
}

Push-Location $projectRoot
try {
    flutter build $Target --release --dart-define="DART_MAPS_API_KEY=$mapsApiKey"
}
finally {
    Pop-Location
}
