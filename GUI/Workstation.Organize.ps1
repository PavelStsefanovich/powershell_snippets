[CmdletBinding()]
Param(
  [string]$getProcessWindow
)

function Get-Window {
    <#
        .SYNOPSIS
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .DESCRIPTION
            Retrieve the window size (height,width) and coordinates (x,y) of
            a process window.

        .PARAMETER ProcessName
            Name of the process to determine the window characteristics

        .NOTES
            Name: Get-Window
            Author: Boe Prox
            Version History
                1.0//Boe Prox - 11/20/2015
                    - Initial build

        .OUTPUT
            System.Automation.WindowInfo

        .EXAMPLE
            Get-Process powershell | Get-Window

            ProcessName Size     TopLeft  BottomRight
            ----------- ----     -------  -----------
            powershell  1262,642 2040,142 3302,784

            Description
            -----------
            Displays the size and coordinates on the window for the process PowerShell.exe

    #>
    [OutputType('System.Automation.WindowInfo')]
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipelineByPropertyName=$True)]
        $ProcessName
    )
    Begin {
        Try{
            [void][Window]
        } Catch {
        Add-Type @"
              using System;
              using System.Runtime.InteropServices;
              public class Window {
                [DllImport("user32.dll")]
                [return: MarshalAs(UnmanagedType.Bool)]
                public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
              }
              public struct RECT
              {
                public int Left;        // x position of upper-left corner
                public int Top;         // y position of upper-left corner
                public int Right;       // x position of lower-right corner
                public int Bottom;      // y position of lower-right corner
              }
"@
        }
    }
    Process {
        Get-Process -Name $ProcessName | ForEach {
            $Handle = $_.MainWindowHandle
            $Rectangle = New-Object RECT
            $Return = [Window]::GetWindowRect($Handle,[ref]$Rectangle)
            If ($Return) {
                $Height = $Rectangle.Bottom - $Rectangle.Top
                $Width = $Rectangle.Right - $Rectangle.Left
                $Size = New-Object System.Management.Automation.Host.Size -ArgumentList $Width, $Height
                $TopLeft = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Left, $Rectangle.Top
                $BottomRight = New-Object System.Management.Automation.Host.Coordinates -ArgumentList $Rectangle.Right, $Rectangle.Bottom
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    Write-Warning "Window is minimized! Coordinates will not be accurate."
                }
                $Object = [pscustomobject]@{
                    ProcessName = $ProcessName
                    Size = $Size
                    TopLeft = $TopLeft
                    BottomRight = $BottomRight
                }
                $Object.PSTypeNames.insert(0,'System.Automation.WindowInfo')
                $Object
            }
        }
    }
}

function global:Set-Window()
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $FilePath,

    [Parameter(Mandatory = $true)]
    [int] $PosX,

    [Parameter(Mandatory = $true)]
    [int] $PosY,

    [Parameter(Mandatory = $false)]
    [int] $Height = -1,

    [Parameter(Mandatory = $false)]
    [int] $Width = -1,

    [Parameter(Mandatory = $false, ValueFromRemainingArguments=$true)]
    $StartProcessParameters
  )

  # Invoke process
  #$process = "Start-Process -FilePath $FilePath -PassThru $StartProcessParameters" | Invoke-Expression
	$processes = get-process $FilePath -errorAction SilentlyContinue

 if ($processes.count -gt 0) {
  foreach ($process in $processes) {

	$mainWindowHandle = [int]$process.mainWindowHandle

	# Once we grabbed the MainWindowHandle, we need to use the Win32-API function SetWindowPosition (using inline C#)
    if($mainWindowHandle -ne 0)
    {
		write-verbose ("Resizing: " + $process.ProcessName)

		[Win32.NativeMethods]::ShowWindowAsync($mainWindowHandle, 4) | out-null

        $CSharpSource = @"
            using System;
            using System.Runtime.InteropServices;

            namespace TW.Tools.InlinePS
            {
                public static class WindowManagement
                {
                    [DllImport("user32.dll", EntryPoint = "SetWindowPos")]
                    public static extern IntPtr SetWindowPos(IntPtr hWnd, int hWndInsertAfter, int x, int Y, int cx, int cy, int wFlags);

                    public const int SWP_NOSIZE = 0x01, SWP_NOMOVE = 0x02, SWP_SHOWWINDOW = 0x40, SWP_HIDEWINDOW = 0x80;

                    public static void SetPosition(IntPtr handle, int x, int y, int width, int height)
                    {
                        if (handle != null)
                        {
                            SetWindowPos(handle, 0, x, y, 0, 0, SWP_NOSIZE | SWP_HIDEWINDOW);

                            if (width > -1 && height > -1)
                                SetWindowPos(handle, 0, 0, 0, width, height, SWP_NOMOVE);

                            SetWindowPos(handle, 0, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_SHOWWINDOW);
                        }
                    }
                }
            }
"@

        Add-Type -TypeDefinition $CSharpSource -Language CSharp -ErrorAction SilentlyContinue -ErrorVariable nl
        [TW.Tools.InlinePS.WindowManagement]::SetPosition($mainWindowHandle, $PosX, $PosY, $Width, $Height);
    }
  }
 }
}

function global:Set-RegistryKey ()
{
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Path,

    [Parameter(Mandatory = $true, Position = 1)]
    [string] $Key,

    [Parameter(Mandatory = $false)]
    [string] $Value,

    [Parameter()]
    [alias("Type")]
    [ValidateSet("String","DWORD")]
    [string] $ValueType,

    [Parameter()]
    [switch] $Delete
  )

	if ($Delete)
	{
		 Remove-ItemProperty $Path -Name Key -Force
	}
	else
	{
		if (!$ValueType) {$ValueType = "String"}
		if (!$Value) {
			if ($ValueType.ToLower() -eq 'string') {$Value = ""}
			if ($ValueType.ToLower() -eq 'dword') {$Value = 0}
		}
		Set-ItemProperty $Path -PSProperty $Key -Value $Value -Type $ValueType -Force
	}
}

function Fit-WindowToDisplay ($display,$appConfig) {
  $minX = $display.WorkingArea.Left + 2
  $maxX = $display.WorkingArea.Right - 2
  $minY = $display.WorkingArea.Top + 2
  $maxY = $display.WorkingArea.Bottom - 2

  if (($appConfig.PosX + $appConfig.Width) -gt $maxX) {
    if ($appConfig.FixedSize) {
      $appConfig.PosX = $maxX - $appConfig.Width
    } else {
      $appConfig.Width = $maxX - $appConfig.PosX
    }
  }
  if ($appConfig.PosX -lt $minX) {
    $appConfig.PosX = $minX
  }

  if (($appConfig.PosY + $appConfig.Height) -gt $maxY) {
    $appConfig.Height = $maxY - $appConfig.Posy
  }
  if ($appConfig.PosY -lt $minY) {
    $appConfig.PosY = $minY
  }

  return $appConfig
}

function Get-TargetDisplay ($Displays,[string]$preferredOrientation,[int]$preferredDisplayIndex) {
  if ($Displays.count -eq 1) {
    return $Displays[0]
  }

  $targetOrientationDisplays = $Displays | ?{$_.Orientation -eq $preferredOrientation}
  if ($targetOrientationDisplays) {

    if ($targetOrientationDisplays | ?{$_.DisplayIndex -eq $preferredDisplayIndex}) {
      return ($targetOrientationDisplays | ?{$_.DisplayIndex -eq $preferredDisplayIndex})
    }
    if ($preferredOrientation -eq 'landscape') {
      return $targetOrientationDisplays[0]
    }
    if ($preferredOrientation -eq 'portrait') {
      return $targetOrientationDisplays[$targetOrientationDisplays.count - 1]
    }
    return $null

  } else {

    if ($Displays[$preferredDisplayIndex]) {
      return $Displays[$preferredDisplayIndex]
    } else {
      if ($preferredOrientation -eq 'landscape') {
        return $Displays[0]
      }
      if ($preferredOrientation -eq 'portrait') {
        return $Displays[$Displays.count - 1]
      }
    }
    return $null
  }

}


#=== BEGIN

$errorPref = "!!ERROR:"

Add-Type -AssemblyName System.Windows.Forms

#- find all Displays
$Displays = [System.Windows.Forms.Screen]::AllScreens | sort {$_.Bounds.X}
$displayIndex = 0
foreach ($display in $Displays) {
  if (!$display.DisplayIndex) {
    $display | Add-Member -NotePropertyName DisplayIndex -NotePropertyValue $displayIndex -force
  }
  $displayIndex++

  if (!$display.Orientation) {
    if ($display.Bounds.Height -gt $display.Bounds.Width) {
      $display | Add-Member -NotePropertyName Orientation -NotePropertyValue portrait
    } else {
      $display | Add-Member -NotePropertyName Orientation -NotePropertyValue landscape
    }
  }
}

#- get process window config only
if ($getProcessWindow) {
  try {
    $processWindow = get-process $getProcessWindow -errorAction Stop | Get-Window
    $processWindow
    foreach ($display in $Displays) {
      if (($processWindow.TopLeft.X -ge $display.Bounds.Left) -and ($processWindow.TopLeft.X -le $display.Bounds.Right)) {
        Write-Host "Display index: $($display.DisplayIndex)`n"
      }
    }
  } catch{
    Write-Warning "Process not found: <$getProcessWindow>"
  }
  exit
}

#- Explorer
$shell = New-Object -ComObject Shell.Application
$explorerWindows = @()
$explorerWindowsSorted = @()
$nextPosition = 'Top'
$shell.Windows() | %{$explorerWindows += $_}
$commonDirectories = @{
    'Workshop' = 'Top';
    'WORKING.COPY' = 'Bottom'
}

foreach ($window in $explorerWindows) {
    $commonDirPosition = $null
    foreach ($commonDir in $commonDirectories.GetEnumerator().Name) {
        if ($window.LocationURL -like "*/$commonDir*") {
            $commonDirPosition = $commonDirectories.$commonDir
            if ($commonDirPosition -is [array]) {
                throw "$errorPref More than one configuration specified for common directory."
            }
        }
    }

    if ($commonDirPosition) {
        $display = Get-TargetDisplay $Displays -preferredOrientation 'landscape' -preferredDisplayIndex 0
        $positionSwitch = $commonDirPosition
    } else {
        $display = Get-TargetDisplay $Displays -preferredOrientation 'landscape' -preferredDisplayIndex 1
        $positionSwitch = $nextPosition
    }

    $positionOptions = @{
        'Top' = @{
            'Name' = 'explorer';
            'PosX' = $display.WorkingArea.Right - 2 - 602
            'PosY' = $display.WorkingArea.Top + 2
            'Height' = 542;
            'Width' = 602;
            'FixedSize' = $false
        };
        'Bottom' = @{
            'Name' = 'explorer';
            'PosX' = $display.WorkingArea.Right - 2 - 602
            'PosY' = $display.WorkingArea.Bottom - 2 - 542
            'Height' = 542;
            'Width' = 602;
            'FixedSize' = $false
        };
    }
    
    if ($positionOptions.$positionSwitch) {
        $appConfig = Fit-WindowToDisplay -display $display -appConfig $positionOptions.$positionSwitch
    } else {
        throw "$errorPref Specified position is not in list of allowed options: '$($positionOptions.$positionSwitch)'"
    }

    $window.Left = $appConfig.PosX
    $window.Top = $appConfig.PosY
    $window.Width = $appConfig.Width
    $window.Height = $appConfig.Height

    $nextPositionCurrentIndex = ($positionOptions.GetEnumerator().name | sort -Descending).indexof($nextPosition)
    if ($nextPositionCurrentIndex -lt ($positionOptions.GetEnumerator().name.length - 1)) {
        $nextPosition = ($positionOptions.GetEnumerator().name | sort -Descending)[$nextPositionCurrentIndex + 1]
    } else {
        $nextPosition = ($positionOptions.GetEnumerator().name | sort -Descending)[0]
    }
}

#- Applications
$ApplicationsConfig = @()

#@@AppsStart@@
$name = 'lync'
$display = Get-TargetDisplay $Displays -preferredOrientation 'landscape' -preferredDisplayIndex 0
$width = 403
$height = 613
$posX = $display.WorkingArea.Right - 2 - $width
$posY = $display.WorkingArea.Top + 2
$appConfig = @{'Name'=$name; 'PosX'=$posX; 'PosY'=$posY; 'Height'=$height; 'Width'=$width; 'FixedSize'=$true}
$appConfig = Fit-WindowToDisplay -display $display -appConfig $appConfig
$ApplicationsConfig += $appConfig
#@app

$name = 'outlook'
$display = Get-TargetDisplay $Displays -preferredOrientation 'landscape' -preferredDisplayIndex 1
$width = 1853
$height = 1073
$posX = $display.WorkingArea.left - 1
$posY = $display.WorkingArea.Top -1
$appConfig = @{'Name'=$name; 'PosX'=$posX; 'PosY'=$posY; 'Height'=$height; 'Width'=$width; 'FixedSize'=$false}
$appConfig = Fit-WindowToDisplay -display $display -appConfig $appConfig
$ApplicationsConfig += $appConfig
#@app

#- chrome
$name = 'chrome'
$display = Get-TargetDisplay $Displays -preferredOrientation 'landscape' -preferredDisplayIndex 0
$width = 1450
$height = 1000
$posX = $display.WorkingArea.left
$posY = $display.WorkingArea.Top + 2
$appConfig = @{'Name'=$name; 'PosX'=$posX; 'PosY'=$posY; 'Height'=$height; 'Width'=$width; 'FixedSize'=$false}
$appConfig = Fit-WindowToDisplay -display $display -appConfig $appConfig
$ApplicationsConfig += $appConfig
#@app

$name = 'notepad'
$display = Get-TargetDisplay $Displays -preferredOrientation 'landscape' -preferredDisplayIndex 1
$width = 900
$height = 630
$posX = $display.WorkingArea.left + 2
$posY = $display.WorkingArea.Top + 2 - $height
$appConfig = @{'Name'=$name; 'PosX'=$posX; 'PosY'=$posY; 'Height'=$height; 'Width'=$width; 'FixedSize'=$false}
$appConfig = Fit-WindowToDisplay -display $display -appConfig $appConfig
$ApplicationsConfig += $appConfig
#@app

$name = 'RDCMan'
$display = Get-TargetDisplay $Displays -preferredOrientation 'landscape' -preferredDisplayIndex 1
$width = 1450
$height = 1000
$posX = $display.WorkingArea.Right - $width
$posY = $display.WorkingArea.Bottom - 2 - $height
$appConfig = @{'Name'=$name; 'PosX'=$posX; 'PosY'=$posY; 'Height'=$height; 'Width'=$width; 'FixedSize'=$false}
$appConfig = Fit-WindowToDisplay -display $display -appConfig $appConfig
$ApplicationsConfig += $appConfig
#@app

$name = 'powershell'
$display = Get-TargetDisplay $Displays -preferredOrientation 'landscape' -preferredDisplayIndex 1
$width = 900
$height = 630
$posX = $display.WorkingArea.left
$posY = $display.WorkingArea.Bottom - 2 - $height
$appConfig = @{'Name'=$name; 'PosX'=$posX; 'PosY'=$posY; 'Height'=$height; 'Width'=$width; 'FixedSize'=$false}
$appConfig = Fit-WindowToDisplay -display $display -appConfig $appConfig
$ApplicationsConfig += $appConfig
#@app

$name = 'atom'
$display = Get-TargetDisplay $Displays -preferredOrientation 'portrait' -preferredDisplayIndex 2
$width = 1090
$height = 1670
$posX = $display.WorkingArea.left
$posY = $display.WorkingArea.top + 70
$appConfig = @{'Name'=$name; 'PosX'=$posX; 'PosY'=$posY; 'Height'=$height; 'Width'=$width; 'FixedSize'=$false}
$appConfig = Fit-WindowToDisplay -display $display -appConfig $appConfig
$ApplicationsConfig += $appConfig
#@app

$name = 'code'
$display = Get-TargetDisplay $Displays -preferredOrientation 'portrait' -preferredDisplayIndex 2
$width = 1090
$height = 1670
$posX = $display.WorkingArea.left
$posY = $display.WorkingArea.top + 70
$appConfig = @{'Name'=$name; 'PosX'=$posX; 'PosY'=$posY; 'Height'=$height; 'Width'=$width; 'FixedSize'=$false}
$appConfig = Fit-WindowToDisplay -display $display -appConfig $appConfig
$ApplicationsConfig += $appConfig
#@app

$name = 'notepad++'
$display = Get-TargetDisplay $Displays -preferredOrientation 'portrait' -preferredDisplayIndex 2
$width = 1090
$height = 1670
$posX = $display.WorkingArea.left
$posY = $display.WorkingArea.top + 170
$appConfig = @{'Name'=$name; 'PosX'=$posX; 'PosY'=$posY; 'Height'=$height; 'Width'=$width; 'FixedSize'=$false}
$appConfig = Fit-WindowToDisplay -display $display -appConfig $appConfig
$ApplicationsConfig += $appConfig
#@app
#@@AppsEnd@@

#- set windows
$ErrorActionPreference = "SilentlyContinue" #comment this out to debug

write-verbose " >>> Active windows"
$sig = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
Add-Type -MemberDefinition $sig -name NativeMethods -namespace Win32

foreach ($appConfig in $ApplicationsConfig) {
  if ($appConfig.FixedSize) {
    Set-Window $appConfig.Name -PosX $appConfig.PosX -PosY $appConfig.PosY
  } else {
    Set-Window $appConfig.Name -PosX $appConfig.PosX -PosY $appConfig.PosY -Height $appConfig.Height -Width $appConfig.Width
  }
}

#(ps) registry tweaks excluded because they resulted in system instability (probably due to blackberry forcing policies)
exit

write-verbose " >>> Registry tweaks"

write-verbose "UAC: don't dim desktop"
Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Key "ConsentPromptBehaviorAdmin" -Value "5"
Set-RegistryKey -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Key "PromptOnSecureDesktop" -Value "0"
