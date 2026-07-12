<#
.SYNOPSIS
Build script for FinalizeAndArchiveProject module

.DESCRIPTION
This script handles building, testing, and publishing the module
#>

param (
    [string[]] $Tasks = @('Build'),
    [switch] $ResolveDependency,
    [switch] $UseModuleFast
)

$ErrorActionPreference = 'Stop'

$modulePath = $PSScriptRoot
$sourcePath = Join-Path -Path $modulePath -ChildPath 'source'
$outputPath = Join-Path -Path $modulePath -ChildPath 'output'
$requiredModulesPath = Join-Path -Path $outputPath -ChildPath 'RequiredModules'

if ($ResolveDependency) {
    Write-Host "Resolving dependencies..."

    $requiredModules = @(
        @{
            Name    = 'PSToml'
            Version = '0.5.0'
        }
    )

    foreach ($module in $requiredModules) {
        $moduleOutputPath = Join-Path -Path $requiredModulesPath -ChildPath $module.Name
        if (-not (Test-Path -Path $moduleOutputPath)) {
            Write-Host "Installing $($module.Name)..."
            if ($UseModuleFast) {
                Save-ModuleFast -Name $module.Name -Version $module.Version -Path $requiredModulesPath -Force
            }
            else {
                Save-Module -Name $module.Name -RequiredVersion $module.Version -Path $requiredModulesPath -Force
            }
        }
    }
}

if ($Tasks -contains 'Build') {
    Write-Host "Building module..."

    $moduleName = 'FinalizeAndArchiveProject'
    $buildOutputPath = Join-Path -Path $outputPath -ChildPath $moduleName

    if (Test-Path -Path $buildOutputPath) {
        Remove-Item -Path $buildOutputPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $buildOutputPath -Force | Out-Null

    Copy-Item -Path (Join-Path -Path $sourcePath -ChildPath '*') -Destination $buildOutputPath -Recurse -Force

    Write-Host "Module built successfully at $buildOutputPath"
}

if ($Tasks -contains 'Test') {
    Write-Host "Running tests..."
    $testResults = Invoke-Pester -Path (Join-Path -Path $modulePath -ChildPath 'tests') -PassThru
    if ($testResults.FailedCount -gt 0) {
        Write-Error "Tests failed"
        exit 1
    }
    Write-Host "All tests passed"
}