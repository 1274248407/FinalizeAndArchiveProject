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

if ($ResolveDependency)
{
    Write-Output 'Resolving dependencies...'

    $requiredModules = @(
        @{
            Name    = 'PSToml'
            Version = '0.5.0'
        }
    )

    foreach ($module in $requiredModules)
    {
        $moduleOutputPath = Join-Path -Path $requiredModulesPath -ChildPath $module.Name
        if (-not (Test-Path -Path $moduleOutputPath))
        {
            Write-Output "Installing $($module.Name)..."
            if ($UseModuleFast)
            {
                Save-ModuleFast -Name $module.Name -Version $module.Version -Path $requiredModulesPath -Force
            }
            else
            {
                Save-Module -Name $module.Name -RequiredVersion $module.Version -Path $requiredModulesPath -Force
            }
        }
    }
}

if ($Tasks -contains 'Build')
{
    Write-Output 'Building module...'

    $moduleName = 'FinalizeAndArchiveProject'
    $buildOutputPath = Join-Path -Path $outputPath -ChildPath $moduleName

    if (Test-Path -Path $buildOutputPath)
    {
        Remove-Item -Path $buildOutputPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $buildOutputPath -Force | Out-Null

    Copy-Item -Path (Join-Path -Path $sourcePath -ChildPath '*') -Destination $buildOutputPath -Recurse -Force

    Write-Output "Module built successfully at $buildOutputPath"
}

if ($Tasks -contains 'Analyze')
{
    Write-Output 'Running script analysis...'
    $analysisFiles = Get-ChildItem -Path $modulePath -Recurse -Include '*.ps1', '*.psm1', '*.psd1' |
        Where-Object { $PSItem.FullName -notmatch 'output|.git|node_modules' }

    $results = @()
    foreach ($File in $analysisFiles)
    {
        $results += Invoke-ScriptAnalyzer -Path $File.FullName -Settings (Join-Path $modulePath 'PSScriptAnalyzerSettings.psd1')
    }

    if ($results)
    {
        Write-Output "`nScript analysis issues found:"
        $results | Format-Table -Property RuleName, Severity, @{n = 'Path'; e = { $PSItem.ScriptPath.Split('\')[-1] } }, Line, Message -AutoSize
        Write-Error 'Script analysis failed'
        exit 1
    }
    Write-Output 'Script analysis passed'
}

if ($Tasks -contains 'Test')
{
    Write-Output 'Running tests...'
    $testResults = Invoke-Pester -Path (Join-Path -Path $modulePath -ChildPath 'tests') -PassThru
    if ($testResults.FailedCount -gt 0)
    {
        Write-Error 'Tests failed'
        exit 1
    }
    Write-Output 'All tests passed'
}