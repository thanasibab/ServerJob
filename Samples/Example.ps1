# Example usage of the module
Start-ServerJob C:\Users\Gkaifes\Documents\Powershell\Modules\ServerJob\Samples\SubJob1.ps1 SubJob

Start-ServerJob C:\Users\Gkaifes\Documents\Powershell\Modules\ServerJob\Samples\SubJob2.ps1 SubJob2

Get-ServerJob

Get-ServerJob -Status Completed | Remove-ServerJob


