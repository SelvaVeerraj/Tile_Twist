# Builds a debug Android APK from the command line.
# Usage (from the project folder):
#   .\tools\export_android.ps1 -Godot "C:\path\to\Godot_v4.3-stable_win64.exe"
# Requirements: Godot export templates installed, and Android SDK + JDK paths
# set in Godot (Editor > Editor Settings > Export > Android).
param(
    [Parameter(Mandatory = $true)][string]$Godot
)
$project = Split-Path -Parent $PSScriptRoot
$out = Join-Path $project "build\android"
New-Item -ItemType Directory -Force $out | Out-Null

# Import assets first (needed on a fresh checkout), then export.
& $Godot --headless --path $project --import
& $Godot --headless --path $project --export-debug "Android" (Join-Path $out "TileTwist.apk")
Write-Host "APK written to $out\TileTwist.apk"
