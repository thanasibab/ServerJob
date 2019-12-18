# Definition of the custom ServerJob class used in the module
class ServerJob {
  [int]$ID
  [string]$Name
  [DateTime]$StartTime
  [DateTime]$EndTime
  [string]$Status
  [bool]$Success
  [string]$ErrorMsg
}

# The array which holds the jobs to be accessed from the Get-ServerJob function
New-Variable PoshSR_Jobs -Value ([System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]@())) -Option ReadOnly -Scope Global -Force

function Start-ServerJob{
    <#
    .Synopsis
      Stores a script as a ServerJob object and runs it

    .Description
      This function receives a script in the form of a file path, adds it to the module array of ServerJobs and runs it, while handling 
      any occurring exceptions. The ID of the jobs is incremented automatically.

    .Parameter FilePath
      The path of the file which contains the script to run

    .Parameter JobName
      The name of the job to run, to be used for identification

    .Parameter JobID
      The id of the job to run, to be used for identification

    .Example
      # Run a job
      Start-ServerJob -FilePath <FILEPATH> -JobName ExampleJob
    #>

    param(
        [Parameter(Mandatory = $True)][String] $FilePath,
        [Parameter(Mandatory = $True)][String] $JobName
    )

    # Creating the job object
    $ServerJob = New-Object ServerJob -Property @{
      ID = $PoshSR_Jobs.Count + 1
      Name = $JobName + $ID
      StartTime = Get-Date
      EndTime = Get-Date
      Status = "Not Started"
      Success = $Null
      ErrorMsg = ""
    }

    # Add the job object to the global array
    $PoshSR_Jobs.Add($ServerJob) | Out-Null
    
    try {
      $ServerJob.StartTime = Get-Date
      $ServerJob.Status = "In Progress"

      & $FilePath | Out-Null

      $ServerJob.Success = $True
      $ServerJob.Status = "Completed"
    }
    # TODO: Add custom exception handling
    catch{
      $ServerJob.Success = $False
      $ServerJob.ErrorMsg = $_
      Write-Host "Error occured during execution of job $JobName."
      Write-Host $_
    }
    finally{
      $ServerJob.EndTime = Get-Date
    }
}
Export-ModuleMember -Function Start-Serverjob


function Get-ServerJob{
  <#
    .Synopsis
      Gets jobs that are currently available in the session

    .Description
      This function will display jobs according to the parameters passed. If no parameters are given, all jobs will be displayed.

    .Parameter Job
      The ServerJob object being looked up

    .Parameter Id
      The ID of the job being looked up

    .Parameter Status
      The status of the job being looked up

    .Example
      # Get a job by id
      Get-ServerJob -Id 14

      # Get all jobs by status
      Get-ServerJob -Status Completed
    #>
  [OutputType('ServerJob')]
  [cmdletbinding(
    DefaultParameterSetName='All'
  )]
  param(
      [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
      ParameterSetName='Job', Position=0)]
      [ServerJob[]]$Job,
      [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
      ParameterSetName='Id', Position=0)]
      [int[]]$Id,

      [Parameter(ParameterSetName='Id')]
      [Parameter(ParameterSetName='All')]
      [string[]]$Status
  )

  Begin {
    $Hash = @{}
    $ResultJobs = New-Object System.Collections.ArrayList
  }

  Process {
    $Property = $PSCmdlet.ParameterSetName

    if ($PSCmdlet.ParameterSetName -eq 'Job') {
      Write-Verbose "Adding Job $($PSBoundParameters[$Property].Id)"
      foreach ($v in $PSBoundParameters[$Property]) {
          $Hash.Add($v.ID,1)
      }
    }
    elseif($PSCmdlet.ParameterSetName -eq 'Id') {
      Write-Verbose "Adding Job $($PSBoundParameters[$Property])"
        foreach ($v in $PSBoundParameters[$Property]) {
            $Hash.Add($v,1)
        }
    }
  }
  End {
    if ($Property -eq 'Job') { $Property = 'ID' }
    $States = if ($PSBoundParameters.ContainsKey('Status')) { '^' + ($Status -join '$|^') + '$' } else { '.' }

    if ($PSCmdlet.ParameterSetName -eq 'All') {
      Write-Verbose 'All Jobs'
      $ResultJobs = $PoshSR_Jobs
    }
    else {
      Write-Verbose "Filtered Jobs by $Property"
      foreach ($job in $PoshSR_Jobs) {
          if ($Hash.ContainsKey($job.$Property))
          {
              [void]$ResultJobs.Add($job)
          }
      }
    }
    foreach ($job in $ResultJobs) {
      if ($job.Status -match $States) {
        $job
      }
    }
  }
}
Export-ModuleMember -Function Get-Serverjob

function Remove-ServerJob{
  <#
    .Synopsis
      Removes jobs that are currently available in the session

    .Description
      This function will remove jobs according to the parameters passed, either by passing the jobs as an object or by id.

    .Parameter Job
      The ServerJob object, or an array of them, to be deleted

    .Parameter Id
      The ID of the job, or an array of job ID's, to be deleted 

    .Parameter Force
      Force a job to be deleted even if it is still running. Currently does not do much as jobs aren't run simultaneously. 

    .Example
      # Remove a job by id
      Remove-ServerJob -Id 14

      # Remove all jobs with the status completed
      Get-ServerJob -Status Completed | Remove-ServerJob
    #>
  [cmdletbinding(
    DefaultParameterSetName='Job',
    SupportsShouldProcess = $True
  )]
  param(
      [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
      ParameterSetName='Job', Position=0)]
      [Alias('InputObject')]
      [ServerJob[]]$Job,
      [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,
      ParameterSetName='Id', Position=0)]
      [int[]]$Id,

      [parameter()]
      [switch]$Force
  )
  
  Begin {
    $List = New-Object System.Collections.ArrayList
  }

  Process {
    $Property = $PSCmdlet.ParameterSetName
    if ($PSBoundParameters[$Property]) {
      Write-Verbose "Adding $($PSBoundParameters[$Property])"
      [void]$List.AddRange($PSBoundParameters[$Property])
    }
  }

  End {
    if (-not $List.Count) { return } # No jobs selected to search
    $PSBoundParameters[$Property] = $List
    [void]$PSBoundParameters.Remove('Force')
    [array]$ToRemove = Get-ServerJob @PSBoundParameters
    if ($ToRemove.Count) {
        [System.Threading.Monitor]::Enter($PoshSR_Jobs.syncroot)
        try {
            $ToRemove | ForEach-Object {
                If ($PSCmdlet.ShouldProcess("Name: $($_.Name), associated with JobID $($_.ID)",'Remove')) {
                    If ($_.Status -notmatch 'Completed|Failed|Stopped') {
                        If ($Force) {
                            $PoshSR_Jobs.Remove($_)
                        } Else {
                            Write-Error "Unable to remove job $($_.ID)"
                        }
                    } Else {
                        [void]$PoshSR_Jobs.Remove($_)
                    }
                }
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($PoshSR_Jobs.syncroot)
        }
    }
}
}
Export-ModuleMember -Function Remove-Serverjob