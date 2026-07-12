function Invoke-ArchiveProject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ProjectDir,
        [Parameter(Mandatory = $true)]
        [string] $ArchiveDir
    )

    try {
        $projectName = [System.IO.Path]::GetFileName($ProjectDir)
        $destination = Join-Path -Path $ArchiveDir -ChildPath $projectName

        Move-Item -Path $ProjectDir -Destination $destination -Force
        Write-Information "项目已归档: $ArchiveDir"
        return $true
    }
    catch {
        Write-Error "归档失败: $_"
        return $false
    }
}