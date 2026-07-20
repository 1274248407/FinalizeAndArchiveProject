@{
    RootModule           = 'FinalizeAndArchiveProject.psm1'
    ModuleVersion        = '0.1.0'
    CompatiblePSEditions = @('Core')
    GUID                 = 'b59b8442-9cf9-4c4b-bc40-035336ace574'
    Author               = 'lucas gold'
    CompanyName          = 'lucas gold'
    Copyright            = '(c) lucas gold. All rights reserved.'
    Description          = '高性能项目归档处理工具'
    PowerShellVersion    = '7.0'
    RequiredModules      = @('PSToml')
    FunctionsToExport    = @('Start-FinalizeAndArchive', 'Select-Project')
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Archive', 'Project', 'Finalize')
            ProjectUri   = 'https://github.com/lucasgold/FinalizeAndArchiveProject'
            LicenseUri   = 'https://github.com/lucasgold/FinalizeAndArchiveProject/blob/main/LICENSE'
            ReleaseNotes = 'Initial release'
        }
    }
}