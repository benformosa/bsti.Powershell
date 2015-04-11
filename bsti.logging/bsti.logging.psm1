#  bsti.logging.psm1

<#
  .SYNOPSIS 
  Module file for writing and managing messages to log files.
  
  Required Modules: bsti.conversion
  
  .DESCRIPTION
  
  REVISION HISTORY
  03/28/15 BSTI:  Created
  
  
  .EXAMPLE
  #  Include this script in your script:
  Import-Module bsti.logging

#>

######################################################################################################################################################################################################
#  FUNCTIONS
######################################################################################################################################################################################################

function Get-Timestamp()
{
  <#
    .SYNOPSIS 
    Generates a timestamp for unique file naming.  e.g. 01012010120000  (mmddyyyyHHmmss)
  #>
  
  [CmdletBinding()]
  param
  (
  )
  
  "{0:MMddyyyyHHmmss}" -f (Get-Date)
}

function Remove-LogFiles()
{
  <#
    .SYNOPSIS
    This function will purge similarly-named log files meeting the given criteria.  The last write time on the file is evaluated when considering file age.
    
    .PARAMETER LogFilePattern
    Specifies the name pattern the log file must match to be considered for deletion.  Use * as a wildcard.
    
    .PARAMETER Path
    Specifies one or more paths where the log files reside. 
    
    .PARAMETER PurgeAfter
    If specified, then log files matching the name, path and extension specified that are older than the time specified will be purged.  Specify this value with number of units, then one of the following units: d | h | m (for days, hours, minutes).  Example:  4d (4 days) | 24h (24 hours).
    You can also specify a vaild TimeSpan string:  d.hh:mm[:ss.ttt] If KeepNumberOfFiles is also specified, then both thresholds have to be crossed for a file to be purged.  Default is no files are purged due to age (blank value).
    
    .PARAMETER KeepNumberOfFiles
    If specified, then log files matching the name, path and extension specified that number in excess of the value specified will be purged.  The oldest files are purged first.
    If PurgeAfter is also specified, then both thresholds have to be crossed for a file to be purged.  Default value is -1 (no files purged due to count).
    
    .INPUTS
    You can specify the Path via the pipeline as either a string or System.IO.DirectoryInfo object.
    
    .EXAMPLE
    PS>  Remove-LogFiles -path C:\scripts\logs -LogFilePattern BackupProcess*.log -PurgeAfter "7d"
    #  Purges any log files in c:\scripts\logs matching BackupProcess*.log older than 7 days.
    
    .EXAMPLE
    PS>  Get-Item -Path C:\Scripts\Logs | Remove-LogFiles -LogFilePattern BackupProcess*.log -PurgeAfter "1.12:00:00"
    #  Purges any log files in c:\scripts\logs matching BackupProcess*.log older than 1 day, 12 hours.
        
  #>
  
  [CmdletBinding(SupportsShouldProcess=$true)]
  param
  (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)] [string[]] $Path,
    [Parameter(Mandatory=$true)] [string] $LogFilePattern,
    [string] $PurgeAfter,
    [int] $KeepNumberOfFiles = -1
  )
  
  process
  {
    if ( $PurgeAfter -or $KeepNumberOfFiles -ge 0 )
    {
      foreach ( $p in $Path )
      {
        $deletedFiles = Get-ChildItem -Path $p -Filter $LogFilePattern | Sort-Object -Property LastWriteTime -Descending
        Write-Verbose ("{0:#,##0} files will be evaluated for purging." -f $deletedFiles.Count)
        
        if ( $KeepNumberOfFiles -gt 0 )
        {
          $deletedFiles = $deletedFiles | Select-Object -Skip $KeepNumberOfFiles
          Write-Verbose ("Keeping latest $KeepNumberOfFiles.  {0:#,##0} files will be evaluated for purging." -f $deletedFiles.Count)
        }
        
        if ( $PurgeAfter )
        {
          $purgeTimeSpan = $PurgeAfter | ConvertTo-TimeSpan
          $deletedFiles = $deletedFiles | Where-Object { (New-TimeSpan -Start $_.LastWriteTime) -gt $purgeTimeSpan }
          Write-Verbose ("Deleting files older than $PurgeTimeSpan.  {0:#,##0} files will be purged." -f $deletedFiles.Count)
        }
        
        if ( $deletedFiles )
        {
          $deletedFiles | ForEach-Object { Write-Verbose ("Deleting: {0} ({1})" -f $_.FullName,$_.LastWriteTime); $_ | Remove-Item -Force }
        }
      }
    }
    else
    {
      Write-Warning ("No purge criteria was issued.  No log files will be purged!")
    }
  }
}

function Get-ActiveLogFile()
{
  <#
    .SYNOPSIS 
    This function returns a handle to the currently-active log file.
    
    .OUTPUTS
    [System.Io.FileInfo]
    Returns the active log file.
  #>
  
  [CmdletBinding()]
  param
  (
  )
  
  $script:ActiveLogFile
}

function New-LogFile()
{
  <#
    .SYNOPSIS 
    This function initializes a new log file with the given naming you specify.  This log file is set as the active log file, and any subsequent Write-* functions write to this file.
    
    .DESCRIPTION
    No log file gets created until Write-Message is called for the first time.  If Append is specified as FALSE, any existing log file is deleted by this function.  Also, this function saves the path to the log file
    in $script:ActiveLogFile, which will cause Write-Message to write to this file even if you do not specify the -LogFile parameter.
    
    .PARAMETER Path
    Specifies the full path to the log file you will be writing to.  
    
    .PARAMETER LogFileNameType
    Specify Standard,Circular, or DateStamped.  This determines if the log file name you pass in gets modified to make it unique.  
    Standard - Log file name you pass in is used exactly as it is specified.  This is the default.
    Circular - Log file name is suffixed with _WeekDayName  (Example:  Mylog_Friday.log).  This log file type will be overwritten the next week, so that only 7 log files ever exist at a given time.
    DateStamped - Log file name is suffixed with _MMddyyyyHHmmss.  The number of these files kept can be maintained with the KeepForDays and/or KeepNumberOfFiles parameters.
    
    .PARAMETER Transient
    If specified, then the $script:ActiveLogFile value will not be changed.
    
    .PARAMETER Append
    If specified, then the log file, if already existing, is appended to.  If specified negatively, then it will be overwritten.  Default is overwrite.

    .PARAMETER PurgeAfter
    If specified, then log files matching the name, path and extension specified that are older than the time specified will be purged.  Specify this value with number of units, then one of the following units: d | h | m (for days, hours, minutes).  Example:  4d (4 days) | 24h (24 hours).
    You can also specify a vaild TimeSpan string:  d.hh:mm[:ss.ttt] If KeepNumberOfFiles is also specified, then both thresholds have to be crossed for a file to be purged.  Default is no files are purged due to age (blank value).
    This setting is ignored if LogFileNameType is not DateStamped.
    
    .PARAMETER KeepNumberOfFiles
    If specified, then log files matching the name, path and extension specified that number in excess of the value specified will be purged.  The oldest files are purged first.
    If PurgeAfter is also specified, then both thresholds have to be crossed for a file to be purged.  Default value is -1 (no files purged due to count).
    This setting is ignored if LogFileNameType is not DateStamped.
    
    .OUTPUTS
    [System.Io.FileInfo]
    Returns the log file that will be written to.
    
    .EXAMPLE
    New-LogFile -Path C:\scripts\MyLog.log
    #  Creates a log file called C:\scripts\MyLog.log
    
    .EXAMPLE
    New-LogFile -Path C:\scripts\MyLog.log -LogFileNameType Circular
    #  Creates a log file called C:\scripts\MyLog_Monday.log.  It will be appended to all day Monday, and the next time it is written to after Monday (presumably the next Monday), it will be overwritten.
    
    .EXAMPLE
    New-LogFile -Path C:\scripts\MyLog.log -LogFileNameType DateStamped
    #  Creates a log file called C:\scripts\MyLog_01012013000000.log.  Assuming the current time is 1/1/2013 12:00:00 AM.    

    .EXAMPLE
    New-LogFile -Path C:\scripts\MyLog.log -LogFileNameType DateStamped -PurgeAfter 3d -KeepNumberOfFiles 10
    #  Creates a log file called C:\scripts\MyLog_01012013000000.log.  Assuming the current time is 1/1/2013 12:00:00 AM.  Any files that are older than 3 days AND in excess of 10 files will be deleted.      
  #>
  
  [CmdletBinding(SupportsShouldProcess=$true)]
  param
  (
    [Parameter(Mandatory=$true)] [string] $Path,
    [ValidateSet("Standard","Circular","DateStamped")] [string] $LogFileNameType = "Standard",
    [switch] $Append,
    [switch] $Transient,
    [string] $PurgeAfter,
    [int] $KeepNumberOfFiles = -1
  )
  
  #  The Path specifiec cannot be an existing directory:
  if ( (Test-Path -Path $Path) -and ((Get-Item -Path $Path) -is [System.IO.DirectoryInfo]) )
  {
    throw ("$Path is an existing directory!  You must specify the full path to a possible file!")
  }  
  
  $extension = [System.IO.Path]::GetExtension($path)
  $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
  $logFilePath = (Split-Path -Path $Path)
  
  if ( $LogFileNameType -ieq "circular" )
  {
    #  Append by default:
    $Append = $True
    
    $logFileName = "{0}_{1}{2}" -f $fileName,(Get-Date).DayOfWeek.ToString(),$extension
    $Path = Join-Path -Path $logFilePath -ChildPath $logFileName
    
    if ( (Test-Path -Path $Path -PathType Leaf) -and (New-TimeSpan -Start (Get-Item -Path $Path).LastWriteTime -End (Get-Date)).TotalDays -ge 1  )
    {
      #  File hasn't been written to since last week, overwrite:
      $Append = $false
    }
  }
  elseif ( $LogFileNameType -ieq "datestamped" )
  {
    $logFileName = "{0}_{1}{2}" -f $fileName,(Get-TimeStamp),$extension
    $Path = Join-Path -Path $logFilePath -ChildPath $logFileName
    
    #  Purge any files if specified:
    if ( $KeepNumberOfFiles -ge 0 -or $PurgeAfter )
    {
      #  In keeping a number of files, count the newly-created log file:
      if ( $KeepNumberOfFiles -gt 0 )
      {
        $KeepNumberOfFiles --
      }
      
      Remove-LogFiles -Path $logFilePath -LogFilePattern ("$fileName`*$extension") -KeepNumberOfFiles $KeepNumberOfFiles -PurgeAfter $PurgeAfter
    }    
  }
  
  #  Create the log file directory if it does not exist:
  if ( !(Test-Path -Path $logFilePath -PathType Container) )
  {
    New-Item -ItemType Directory -Path $logFilePath -Force -WhatIf:$false | Out-Null
  }
   
  if ( (Test-Path -Path $Path -PathType Leaf) )
  { 
    #  File alredy exists:
    if ( $Append )
    {
      #  Append to the existing file:
      Get-Item -Path $Path
    }
    else
    {
      Write-Verbose "Log file at $Path will be overwritten."
      
      #  Delete the file first:
      Remove-Item -Path $Path -Confirm:$false -Force
    }
  }
  
  if ( !(Test-Path -Path $Path -PathType Leaf) )
  {
    #  File does not exist, create it:
    New-Item -ItemType File -Path $Path -Force -Confirm:$false -WhatIf:$false
  }
  
  if ( !$Transient )
  {
    $script:ActiveLogFile = Get-Item -Path $Path
  }
}

function Write-Message()
{
  <#
    .SYNOPSIS 
    Logs a time stamped message to the console and/or a log file.  If a log file is specified explicitly or if New-LogFile was not used to create a new active log file, the message is only echoed to the console.
  
    .PARAMETER Message
    Specifies the message to output.

    .PARAMETER WriteVerbose
    Only writes and logs the message if the VerbosePreference is set.
    
    .PARAMETER WriteWarning
    Writes the message the warning output stream (dependent on WarningPreference).
    
    .PARAMETER WriteDebug
    Only writes and logs the message if the DebugPreference is set.
    
    .PARAMETER NoTimeStamp
    Omits the time stamp from the log message.
    
    .PARAMETER ForegroundColor
    Specifies the color to use for the font when outputting to the console.
    
    .PARAMETER LogFile
    Specifies the path to the log file to write the message to.  If not specified, then the active log file created by New-LogFile will be used. 

    .INPUTS
    You can pass the message to be logged via the Pipeline:  "Log this message" | Write-Message
    
    .EXAMPLE
    PS>  Write-Message "Test message"
    # Logs the message "Test message" with a time stamp.  If NewLogFile was called beforehand, then it will also log this message to that file.    
    
    .EXAMPLE
    PS> Write-Message -Message "Test message" -LogFile "C:\scripts\log\test.log" -ForegroundColor "green"
    #  Logs the message "Test message" to the console (in green) and to the log file at the specified path.  If the log file does not exist, it will be created.    

    .EXAMPLE
    PS> Get-Date | Write-Message
    #  Logs the current date to the consoel and if NewLogFile was called beforehand, then it will also log this message to that file.
  #>
    
  [CmdletBinding()]
  param
  (
    [Parameter(Position=0,ValueFromPipeline=$true)][string[]] $Message, 
    [string] $LogFile, 
    [Alias("OmitTimestamp")][switch] $NoTimeStamp, 
    [string] $ForegroundColor = $host.ui.rawui.ForegroundColor,
    [switch] $WriteVerbose,
    [switch] $WriteError,
    [switch] $WriteDebug,
    [switch] $WriteWarning
  )
  
  begin
  {
    if ( !$LogFile -and (Get-Variable | Where-Object { $_.Name -ieq "ActiveLogFile" } ) )
    {
      $LogFile = $script:ActiveLogFile
    }
    
    if ( !$ForegroundColor )
    {
      $ForegroundColor = $host.ui.rawui.ForegroundColor
    }

    #  Powershell ISE does not show a default UI foreground color.  Default to DarkYellow.
    if ( $ForegroundColor -ieq -1 )
    {
      $ForegroundColor = "DarkYellow"
    }
  }
  
  process
  {
    foreach ( $msg in $Message )
    {
      #  Add the timestamp:
    	if ( !$NoTimeStamp )
    	{
    		$msg = ("{0:mm/dd/yyyy hh:mm:ss tt} - {1}" -f (Get-Date),$msg)
    	}
      
      #  Write to the console:  
      if ( $WriteVerbose )
      {
        Write-Verbose $msg
        $msg = ("VERBOSE:  $msg")
      }
      elseif ( $WriteDebug )
      {
        Write-Debug $msg
        $msg = ("DEBUG:  $msg")
      }
      elseif ( $WriteError )
      {
        Write-Error $msg
        $msg = ("ERROR:  $msg")
      }
      elseif ( $WriteWarning )
      {
        Write-Warning $msg
        $msg = ("WARNING:  $msg")
      }
      else
      {
        Write-Host $msg -ForegroundColor $ForegroundColor
      }
      
      #  Write to the log file if specified:	
    	if ( $LogFile )
    	{
        if ( (!$WriteVerbose -or ($WriteVerbose -and $VerbosePreference -ieq "CONTINUE")) -and (!$WriteDebug -or ($WriteDebug -and $DebugPreference -ieq "CONTINUE")) -and (!$WriteWarning -or ($WriteWarning -and $WarningPreference -ieq "CONTINUE")) )
        {
          $success = $false
          $retries = 0
          $errorMsg = ""
          
          #  Sometimes the log file is locked open briefly by other applicatios, such as when the person running the script is watching it as the script runs:
          while ( !$success -and $retries -lt 5 )
          {
            $retries ++
            
            try
            {
              Add-Content -Path $LogFile -Value $msg -Force -ErrorAction Stop -WhatIf:$false -Confirm:$false
              $success = $true
            }
            catch
            {
              $errorMsg = $_.Exception.Message
              Start-Sleep -Seconds 2
            }
          }
          
          if ( !$success )
          {
            Write-Host "Error logging to file!"
            
            if ( $ErrorActionPreference -ieq "Stop" )
            {
              throw $errorMsg
            }
            else
            {
              Write-Host $errorMsg -ForegroundColor Red
            }
          }
        }
    	}
    }
  }
}

function Write-Object()
{
  <#
    .SYNOPSIS 
    Logs a time stamped message containg the object and its properties to the console and/or a log file.
  
    .PARAMETER ObjectToWrite
    Specifies the object to output.

    .PARAMETER WriteError
    Writes the message to the error output stream.
    
    .PARAMETER WriteVerbose
    Only writes and logs the message if the VerbosePreference is set.
    
    .PARAMETER WriteDebug
    Only writes and logs the message if the DebugPreference is set.
    
    .PARAMETER NoTimeStamp
    Omits the time stamp from the log message.
    
    .PARAMETER ForegroundColor
    Specifies the color to use for the font when outputting to the console.
    
    .PARAMETER LogFile
    Specifies the path to the log file to write the message to.  If not specified, then the active log file created by New-LogFile will be used. 
    
    .INPUTS
    Accepts InputObject from the pipeline.

    .EXAMPLE
    PS> Write-Object -InputObject (Get-ChildItem -path c:\)[0] -LogFile C:\Scripts\log\test.log
    #  Writes the first file found in C:\ 

    .EXAMPLE
    PS> (Get-ChildItem -path c:\temp) | Write-Object -NoTimeStamp
    #  
  #>
  
  [CmdletBinding()]
  param
  (
    [Parameter(Position=0,ValueFromPipeline=$true)][Alias("ObjectToWrite")] [PSObject[]] $InputObject, 
    [Alias("OmitTimestamp")][switch] $NoTimeStamp, 
    [switch] $WriteError, 
    [string] $LogFile, 
    [string] $ForegroundColor = $host.ui.rawui.ForegroundColor, 
    [switch] $WriteVerbose,
    [switch] $WriteDebug,
    [switch] $WriteWarning
  )
  
  process
  {
    foreach ( $obj in $InputObject )
    {
    	if ( ($obj | Get-Member -Name "GetType") -and ($obj.GetType() -eq [System.String]) )
    	{
    		Write-Message -Message $InputObject -NoTimestamp:$NoTimeStamp -logFile $LogFile -ForegroundColor $ForegroundColor -WriteVerbose:$WriteVerbose -WriteDebug:$WriteDebug -WriteWarning:$WriteWarning -WriteError:$WriteError
    	}
    	else
    	{
    		[string]$strOutput = ($obj)
    			
    		if ( ![string]::IsNullOrEmpty($strOutput.Replace(" ", "")) )
    		{
  				$strOutput = ($obj | Format-List -Property * -Force  | Out-String )
    			$strOutput = $strOutput -ireplace "(\n|\r|\r\n)+", "`r`n"
    			Write-Message -Message ($strOutput) -NoTimeStamp:$NoTimeStamp -WriteError:$WriteError -logFile $LogFile -ForegroundColor $ForegroundColor -WriteVerbose:$WriteVerbose -WriteDebug:$WriteDebug -WriteWarning:$WriteWarning 
    		}
    	}
    }
  }
}

function Write-Banner()
{
  <#
    .SYNOPSIS 
    Writes an asterisk banner and message to the log file and console.
  
    .PARAMETER Message
    Specifies the message to show in the banner.

    .PARAMETER ForegroundColor
    Specifies the color to use for the font when outputting to the console.

    .PARAMETER WriteVerbose
    Only writes and logs the message if the VerbosePreference is set.
    
    .PARAMETER WriteDebug
    Only writes and logs the message if the DebugPreference is set.
    
    .PARAMETER OmitTimestamp
    Has no function.  LeFormat-Table in for backward compatibility.
    
    .PARAMETER LogFile
    Specifies the path to the log file to write the message to.  If not specified, then the active log file created by New-LogFile will be used. 
    
    .INPUTS
    Accepts Message from the pipeline.

    .OUTPUTS
    No objects are output from this function.

    .EXAMPLE
    PS> Write-Banner -Message "START SCRIPT" -LogFile C:\scripts\log\test.log
    #  Outputs:
    *****************************************************************************************************************
    *************************  START SCRIPT  ************************************************************************
    *****************************************************************************************************************    
    
    .EXAMPLE
    PS> (Get-Date) | Write-Banner -LogFile C:\scripts\log\test.log
    #  Outputs:
    *****************************************************************************************************************
    *************************  03/29/2015 21:23:57  *****************************************************************
    *****************************************************************************************************************
    
  #>
  
  [CmdletBinding()]
  param
  (
    [Parameter(Position=0,ValueFromPipeline=$true)][Alias("BannerMessage")][string] $Message, 
    [string] $LogFile, 
    [string] $ForegroundColor = $host.ui.rawui.ForegroundColor, 
    [switch] $OmitTimeStamp,
    [switch] $WriteVerbose,
    [switch] $WriteDebug,
    [switch] $WriteWarning
  )
  
	$Banner = "*****************************************************************************************************************"
	
	Write-BlankLines -LogFile $LogFile -WriteVerbose:$WriteVerbose -WriteDebug:$WriteDebug -WriteWarning:$WriteWarning
	Write-Message -Message $Banner -logFile $LogFile -ForegroundColor $ForegroundColor -WriteVerbose:$WriteVerbose -WriteDebug:$WriteDebug -NoTimestamp -WriteWarning:$WriteWarning
	$count = (103 - 19 - ($Message.length))
	
	if ( $count -le 1 )
	{
		$count = 1
	}
	
	Write-Message -Message ("*************************  $Message  {0}" -f (New-Object string -ArgumentList "*",$count)) -LogFile $LogFile -ForegroundColor $ForegroundColor -WriteVerbose:$WriteVerbose -WriteDebug:$WriteDebug -NoTimestamp -WriteWarning:$WriteWarning
	Write-Message -Message $Banner -logFile $LogFile -ForegroundColor $ForegroundColor -WriteVerbose:$WriteVerbose -WriteDebug:$WriteDebug -NoTimestamp -WriteWarning:$WriteWarning
	Write-BlankLines -LogFile $LogFile -WriteVerbose:$WriteVerbose -WriteDebug:$WriteDebug -WriteWarning:$WriteWarning
}

function Write-BlankLines()
{
  <#
    .SYNOPSIS 
    Writes a number of blank lines to the console and log file.
  
    .PARAMETER Lines
    Specifies the number of blank lines to write (Default 1)

    .PARAMETER LogFile
    Specifies the path to the log file to write the message to.  If not specified, then the active log file created by New-LogFile will be used. 
    
    .PARAMETER WriteVerbose
    Only writes and logs the message if the VerbosePreference is set.
    
    .PARAMETER WriteDebug
    Only writes and logs the message if the DebugPreference is set.
    
    .INPUTS
    Accepts Lines from the pipeline.

    .OUTPUTS
    No objects are output from this function.

    .EXAMPLE
    PS> Write-BlankLines -Lines 3 
    #  Outputs 3 blank lines to the console and log file.
        
    .EXAMPLE
    PS> Write-BlankLines -Lines 2 -LogFile "C:\Temp\Log.log"
    #  Outputs 2 blank lines to the provided log file.
  #>
  
  [CmdletBinding()]
  param
  (
    [Parameter(Position=0,ValueFromPipeline=$true)][int] $Lines = 1, 
    [string] $LogFile, 
    [switch] $WriteVerbose,
    [switch] $WriteDebug,
    [switch] $WriteWarning
  )
 
  1..$Lines | Foreach-Object { Write-Message -LogFile $LogFile -Message "" -NoTimestamp -WriteVerbose:$WriteVerbose -WriteDebug:$WriteDebug -WriteWarning:$WriteWarning }
}


#############################################################################################################################################
#  MAIN
#############################################################################################################################################

Write-Verbose "bsti.logging module imported"

Export-ModuleMember -Function * -Alias * -Cmdlet *
