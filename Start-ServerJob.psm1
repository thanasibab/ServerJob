<#
 .Synopsis
  Receives a job and runs it on multiple servers running in parallel

 .Description
  This function allows for parallel execution of a job across multiple servers while keeping track of the number of jobs running and which actually ran or failed. 

 .Parameter Job
  The job to run, either a path to a script or a scriptblock

 .Parameter JobName
  The name of the job to run, to be used for identification and synchronization

 .Parameter ParallelNum
  The number of jobs to run simultaneously, to be also used for nested jobs.
  
 .Parameter DependentJobNames
  An array containing the names of the jobs which need to be completed before the calling job

 .Parameter ServerFile
  A string which holds a path to a file which contains the server names

 .Example
   # Run a single job
   Start-InfraJob -Job ExampleJob.ps1 -JobName ExampleJob -Parallel 4
#>

function Start-ServerJob{
    param(
        [Parameter(Mandatory = $True)][Object] $Job,
        [Parameter(Mandatory = $False)][String] $JobName,
        [Parameter(Mandatory = $False)][int] $ParallelNum,
        # [Parameter(Mandatory = $False)][String[]] $ServerGroup,
        # [Parameter(Mandatory = $False)][String[]] $DependentJobNames,
        [Parameter(Mandatory = $False)][String] $ServerFile
        # [Parameter(Mandatory = $False)][Object[]] $ArgumentList
    )
    try {
      #=============================#
      #  Wait for job dependencies  #
      #=============================#
      # If($DependentJobNames){
      #   Write-Output "Waiting for $DependentJobNames"
      #   Get-Job | Wait-Job
      # }
      #=============================#
      #   Check any requirements    #
      #=============================#

      #=============================#
      #   Execute work on servers   #
      #=============================#
      $Servers = Get-Content $ServerFile
      $Running = 0
      $SleepTimer = 500
      
      foreach($Server in $Servers){
        # Check how many servers are running and wait if they are greater-equal to ParallelNum
        While ($(Get-Job -State Running | Where-Object {$_.Name.Contains($JobName)}).Count -ge $ParallelNum){
          # Write-Progress -Activity "Creating Server List" `
          #                -Status "Waiting for threads to close" `
          #                -CurrentOperation "$Running threads created - $($(Get-Job -state running).count) threads open" `
          #                -PercentComplete ($Running / $Servers.count * 100)  
          Start-Sleep -Milliseconds $SleepTimer
        }
        $Running++

        If ($Job.GetType().fullname -eq "System.Management.Automation.ScriptBlock"){
          Start-Job -ScriptBlock $Job -Name $JobName$Server | Out-Null
        }
        Else{
          try{
            Start-Job -FilePath $Job -Name $JobName$Server | Out-Null
          }
          catch{
            Write-Output "Input file invalid. Ensure that input is either a script block or a valid powershell script path."
          }
        } 
      }
      Wait-Job * | Out-Null
      Write-Output "=====$JobName DONE====="
      Get-Date -format "dd-MMM-yyyy HH:mm:ss"
      Remove-Job *  
    }
    # TODO: Add custom exception handling
    catch{
      Write-Output "Error occured during execution of job $JobName."
    }
    
}
Export-ModuleMember -Function Start-Serverjob