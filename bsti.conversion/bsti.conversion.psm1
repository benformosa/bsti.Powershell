#  bsti.conversion.psm1

<#
  .SYNOPSIS 
  Module file that contains several simple data conversion-related functions.
  
  .DESCRIPTION
  Copy the .psm1 and .psd1 files and their containing directory to a valid module directory. The most common one is:
    C:\windows\system32\windowspowershell\v1.0\modules
    
  REVISION HISTORY
  03/28/15 BSTI:  Created
    
  .EXAMPLE
  #  Include this module in your script:
  Import-Module bsti.conversion
  
  .EXAMPLE
  #  Include this module in your script from a custom location:
  Import-Module c:\mymods\bsti.conversion

#>

######################################################################################################################################################################################################
#  FUNCTIONS
######################################################################################################################################################################################################

function ConvertTo-Timespan()
{
  <#
    .SYNOPSIS
    Converts a value to a Timespan.  Allows values like 1m (1 minute), 2d (2 days), or 3 h (3 hours)
    
    .PARAMETER Time
    Specify a unit of time one of the following formats:  
    x[d|h|m|s] - Where x is a number of units and specify either d (days), h (hours), m (minutes), s (seconds)
    d.hh:mm[.ss.tttt] - With days.hours:minutes:seconds.milliseconds
    
    .INPUTS
    You can specify the Time input value via the pipeline.
    
    .OUTPUTS
    [System.TimeSpan]
        
    .EXAMPLE 
    ConvertTo-Timespan 5m
    #  Returns a timespan representing 5 minutes.
    
    .EXAMPLE
    "3d" | ConvertTo-Timespan 
    #  3 days
    
    .EXAMPLE
    ConvertTo-Timespan 1
    #  1 day
    
    .EXAMPLE
    ConvertTo-TimeSpan "3.12:22:15.55"
    #  3 days, 12 hours, 22 minutes, 15 seconds, 55 milliseconds
  #>
  
  [CmdletBinding()]
  param 
  (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)] [string] $Time
  )
  
  process
  {
    #  Determine if the value was a timespan:
    if ( $Time -imatch "\d+(s|m|h|d)`$" )
    {
      #  Not a native timespan:
      $unitQty = [int](($Time -ireplace "\D","").Trim())
      $unitType = ($Time -ireplace "[^\D]","").Trim()
      $params = @{}
      
      if ( $unitType -ieq "d" )
      {
        $params.Add("Days", $unitQty)
      }
      elseif ( $unitType -ieq "h" )
      {
        $params.Add("Hours", $unitQty)
      }
      elseif ( $unitType -ieq "m" )
      {
        $params.Add("Minutes", $unitQty)
      }
      else
      {
        # Assume seconds:
        $params.Add("Seconds", $unitQty)
      }
      
      New-TimeSpan @params
    }
    else
    {
      $ts = New-TimeSpan
            
      if ( [TimeSpan]::TryParse($Time, [ref]$ts) )
      {
        #  User passed in a Timespan format:
        $ts
      }
      else
      {
        throw ("$Time is not a valid timespan value!")
      }
    }    
  }
}

function ConvertTo-Bytes()
{
  <#  
    .SYNOPSIS
    Converts string values like "1m", "1gb", "1t" to bytes.  Largely unnecessary because Powershell implicitly converts values like 50mb for you.  Howerver, it is useful when you are trying to interpret
      string values where you can't control the output.  Linux df -h is a good example.
    
    .PARAMETER DataSize
    Specifies the string data value to convert.  Specify a number of units (as an integer) followed by a unit type.  Unit Types:
    b = bytes
    k or kb = kilobytes
    m or mb = megabytes
    g or gb = gigabytes
    t or tb = terabytes
    p or pb = petabytes
    e or eb = exabytes
    
    .PARAMETER Base
    Specifies whether you are using base 10 or base 2 sizing.  
    Base 10 - 1 MB (Megabyte) = 1000 kilobytes 
    Base 2  - 1 MiB (Mebibyte) = 1024 kilobytes 
    Default is base 2.
      
    .EXAMPLE 
    PS> ConvertTo-Bytes -DataSize "1mb"       
    # 1 Mib = 1024 kb
    
    .EXAMPLE
    PS> ConvertTo-Bytes -DataSize "1m" -Base 10   
    # 1 MB = 1000 kb
    
    .EXAMPLE
    PS> ConvertTo-Bytes -DataSize "1tb"  
    # 1 Tib = 1024 GB    
    
  #>
  [CmdletBinding()]
  param
  (
    [ValidatePattern("\d+(b|k|m|g|t|p|e)?b?`$")][string] $DataSize,
    [int] $Base = 2
  )
  
  $units = @("k","m","g","t","p","e")
  $str = ($DataSize -ireplace "[a-z]|[A-Z]|\+|\-", "").Trim()

  #  Determine the multiplier for the power, which is based on the unit type:
  $index = 0
  $unitType = $units | Where-Object { $DataSize -imatch $_ }
  if ( $unitType )
  {
    $index = $units.IndexOf($unitType.ToLower()) + 1
  }
  
  #  Determine the power:  10 for base 2, 3 for base 10:
  $pow = 10
  if ( $Base -ieq 10 )
  {
    $pow = 3
  }
  
  [double]($str) * [Math]::Pow($Base,($pow * $index))
}

#############################################################################################################################################
#  MAIN
#############################################################################################################################################

Write-Verbose "bsti.conversion module imported"

Export-ModuleMember -Function * -Alias * -Cmdlet *