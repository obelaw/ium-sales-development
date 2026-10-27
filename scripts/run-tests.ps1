# Run PestPHP test suite for ium-sales
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$moduleDir = Resolve-Path (Join-Path $scriptDir "..\..\ium-sales")

Write-Host "Running PestPHP test suite in: $moduleDir" -ForegroundColor Cyan

Set-Location $moduleDir

if (-not (Test-Path "vendor\bin\pest.bat")) {
    Write-Host "vendor\bin\pest not found. Running composer dump-autoload..." -ForegroundColor Yellow
    composer dump-autoload
}

& ".\vendor\bin\pest" $args
