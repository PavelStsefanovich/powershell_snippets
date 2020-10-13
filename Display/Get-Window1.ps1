param (
	[string]$processName
)


Function Get-Window {
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
                $coordinates = @{}                
                If ($Rectangle.Top -lt 0 -AND $Rectangle.LEft -lt 0) {
                    $coordinates.Minimized = $True
                } else {
                    $coordinates.Minimized = $false
                    $coordinates.Right = $Rectangle.Right
                    $coordinates.Left = $Rectangle.Left
                    $coordinates.Top = $Rectangle.Top
                    $coordinates.Bottom = $Rectangle.Bottom
                    $coordinates.Height = $Rectangle.Bottom - $Rectangle.Top
                    $coordinates.Width = $Rectangle.Right - $Rectangle.Left
                }
                
                return $coordinates
            }
        }
    }
}

$powershellCoordinates = get-process $processName | Get-Window
if ($powershellCoordinates -is [array]) {
    $powershellCoordinates[0]
} else {
    $powershellCoordinates
}