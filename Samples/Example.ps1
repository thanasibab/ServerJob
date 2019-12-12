# Example usage of the module
$scriptBlock = {
    param ($Job, $JobName, $ParallelNum, $ServerFile)
    Start-ServerJob -Job $Job -JobName $JobName -ParallelNum $ParallelNum -ServerFile $ServerFile
}

$SJ1Path = "$PSScriptRoot\SubJob1.ps1"
$SJ2Path = "$PSScriptRoot\SubJob2.ps1"
$SJ3Path = "$PSScriptRoot\SubJob3.ps1"

$ServerFile = "$PSScriptRoot\serverlist.txt"

Write-Output $ServerFile

Write-Output "=====Start of script====="
Get-Date -format "dd-MMM-yyyy HH:mm:ss"

$sj1 = Start-Job -Name sj1 -ScriptBlock $scriptBlock -ArgumentList @($SJ1Path, "SubJob1", 4, $ServerFile)
$sj3 = Start-Job -Name sj3 -ScriptBlock $scriptBlock -ArgumentList @($SJ3Path, "SubJob3", 4, $ServerFile)

Wait-Job $sj1 | Out-Null
$sj2 = Start-Job -Name sj2 -ScriptBlock $scriptBlock -ArgumentList @($SJ2Path, "SubJob2", 4, $ServerFile)

Wait-Job $sj2 | Out-Null
Wait-Job $sj3 | Out-Null

Receive-Job *
Remove-Job *

Write-Output "=====End of Script====="
Get-Date -format "dd-MMM-yyyy HH:mm:ss"