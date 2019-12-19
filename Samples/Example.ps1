# Example usage of the module
Start-ServerJob $PSScriptRoot\SubJob1.ps1 SubJob

Start-ServerJob $PSScriptRoot\SubJob2.ps1 SubJob2

Get-ServerJob

Get-ServerJob -Status Completed | Remove-ServerJob


