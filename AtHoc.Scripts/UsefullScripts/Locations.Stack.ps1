# Location Stack Functions >>
function Add-Location ($name, $location = $PWD.Path, [switch]$force) {
    if (!$Global:Locations) {
        $Global:Locations = @{}
    }

    if ($name -and ($name -match '\W')) {
        throw "Invalid ID name: '$name'."
    }
    
    if (!$name) {
        if ($location -notin $Global:Locations.Values) {
            $i = 1
            while ("loc$i" -in $Global:Locations.Keys) {
                $i++
            }
            $name = "loc$i"
        } else {
            $name = $Global:Locations.GetEnumerator().name | ?{$Global:Locations.$_ -eq $location}
        }
    }

    $location = Convert-Path $location -ErrorAction Stop

    if ($name -in $Global:Locations.Keys) {
        if ($Global:Locations.$name -eq $location) {
            break
        }
        if (!$force) {
            Write-Warning "Location ID '$name' exists with following path: '$($Global:Locations.$name)'."
            Write-Warning "Use -force parameter to overwrite."
            break
        }
    }

    $Global:Locations.last = $PWD.Path
    $Global:Locations.$name = $location
}

function Show-Location ($name, $location) { # this has iisue when run with no added locations
    if (!$Global:Locations) {
        $Global:Locations = @{}
        $Global:Locations.last = $PWD.Path
    }

    $showHash = @{}

    if (!$name -and !$location) {
        $showHash = $Global:Locations.Clone()
    }

    if ($name) {
        if ($name -match '\W') {
            throw "Invalid ID name: '$name'."
        } else {
            $keys = @()
            if ($name -is [array]) {
                $name | %{
                    if ($_ -in $Global:Locations.Keys) {
                        $keys += $name
                    }
                }
            } else {
                if ($name -in $Global:Locations.Keys) {
                    $keys += $name
                }
            }
        }

        $keys | %{$showHash.$_ = $Global:Locations.$_}
    }
    
    if ($location) {
        if ($location -in $Global:Locations.Values) {
            $name = $Global:Locations.GetEnumerator().name | ?{$Global:Locations.$_ -eq $location}
            $showHash.$name = $location
        }
    }

    return $showHash
}

function Switch-Location ($name, $location) {
    if (!$Global:Locations) {
        $Global:Locations = @{}
        $Global:Locations.last = $PWD.Path
    }

    if ($name) {
        if (!$location) {
            if ($name -in $Global:Locations.Keys) {
                $location = $Global:Locations.$name
            } else {
                throw "Location ID '$name' not found."
            }
        }
    } else {
        if (!$location) {
            $location = $Global:Locations.last
        }
    }

    $Global:Locations.last = $PWD.Path
    cd $location
}

function Open-Location ($name, $location) {
    if (!$Global:Locations) {
        $Global:Locations = @{}
        $Global:Locations.last = $PWD.Path
    }

    $openHash = @{}

    if (!$name -and !$location) {
        $openHash = $Global:Locations.Clone()
    }

    if ($name) {
        if ($name -match '\W') {
            throw "Invalid ID name: '$name'."
        } else {
            $keys = @()
            if ($name -is [array]) {
                $name | %{
                    if ($_ -in $Global:Locations.Keys) {
                        $keys += $name
                    }
                }
            } else {
                if ($name -in $Global:Locations.Keys) {
                    $keys += $name
                }
            }
        }

        $keys | %{$openHash.$_ = $Global:Locations.$_}
    }

    if ($location) {
        if ($location -in $Global:Locations.Values) {
            $name = $Global:Locations.GetEnumerator().name | ?{$Global:Locations.$_ -eq $location}
            $openHash.$name = $location
        }
    }

    $openedLocations = @()
    $openHash.Keys | %{
        if ($openHash.$_ -notin $openedLocations) {
            explorer $openHash.$_
            $openedLocations += $openHash.$_
        }
    }
    Remove-Variable openedLocations
}

function Remove-Location ($name, $location) {
    
    if ($Global:Locations) {
        
        $showHash = @{}

        if (!$name -and !$location) {
            $showHash = $Global:Locations.Clone()
        }

        if ($name) {
            if ($name -match '\W') {
                throw "Invalid ID name: '$name'."
            } else {
                $keys = @()
                if ($name -is [array]) {
                    $name | %{
                        if ($_ -in $Global:Locations.Keys) {
                            $keys += $name
                        }
                    }
                } else {
                    if ($name -in $Global:Locations.Keys) {
                        $keys += $name
                    }
                }
                
                if (!$keys -and !$location) {
                    throw ("Location ID '" + ($name -join(',')) + "' not found.")
                }
            }

            $keys | %{$showHash.$_ = $Global:Locations.$_}
        }
    
        if ($location) {
            if ($location -in $Global:Locations.Values) {
                $name = $Global:Locations.GetEnumerator().name | ?{$Global:Locations.$_ -eq $location}
                $showHash.$name = $location
            } else {
                if (!$name) {
                    throw ("Path '$location' not found.")
                }
            }
        }

        if ($showHash.count -gt 0) {
            $showHash.GetEnumerator().name | %{$Global:Locations.Remove($_)}
        }
    }
}

function Clear-Locations ([switch]$all) {
    $Global:Locations.Clear()

    if ($all) {
        $locationsStack_MatchPattern = '\$Global\:Locations\s\=\s\@\{.*\}\s\#\slocations\sstack'
        $profileContent = cat $profile -Encoding Ascii -ErrorAction Stop
        $profileContent_New = @()
        $emptyLineCounter = 0

        $profileContent | %{
            if ($_.Trim().Length -eq 0) {
                $emptyLineCounter++
            } else {
                $emptyLineCounter = 0
            }

            if (($_ -notmatch $locationsStack_MatchPattern) -and ($emptyLineCounter -le 2)) {
                $profileContent_New += $_
            }
        }
        $profileContent_New  | Out-File $profile -Force -ErrorAction Stop
    }
}

function Save-Locations ($file, [switch]$force) {
    if ($file) {
        ni $file -Force:$force -ErrorAction Stop | Out-Null
        $file = Convert-Path $file -ErrorAction Stop
    } else {
        $file = $profile
        if (!(Test-Path $file)) {
            ni $file -Force -ErrorAction Stop | Out-Null
        }
    }

    $locationsStack = "`$Global:Locations = @{"

    $openedLocations = @()
    $Global:Locations.Keys | %{
        $locationsStack += " '$_' = '$($Global:Locations.$_)'; "
    }

    $locationsStack += "} # locations stack"
    
    $locationsStack_MatchPattern = '\$Global\:Locations\s\=\s\@\{\s.*\s\}\s\#\slocations\sstack'
    $fileContent = cat $file -Raw -Encoding Ascii

    if ($fileContent -match $locationsStack_MatchPattern) {
        $fileContent -replace $locationsStack_MatchPattern,$locationsStack | Set-Content $file -NoNewline -Force -Encoding Ascii
    } else {
        "`n",$locationsStack | Out-File $file -Append -Encoding ascii
    }
}

function Load-Locations ($file) {
    if (!$file) {
        $file = $profile
    }

    $locationsStack_MatchPattern = '\$Global\:Locations\s\=\s\@\{\s.*\s\}\s\#\slocations\sstack'
    
    (cat $file -Raw -ErrorAction Stop -Encoding Ascii) -match $locationsStack_MatchPattern | Out-Null

    Invoke-Expression $Matches.0
}
# Location Stack Functions<<

# Install Location Stack

$ErrorActionPreference = 'Stop'

if (!(Test-Path $profile)) {
    ni $profile -Force -ErrorAction Stop | Out-Null
} else {
    cp $profile -Destination "$profile`_bkp" -Force
}

$profileContent = cat $profile -Encoding Ascii
$profileContent_New = @()

$aliases = @(
    "# Location Stack Aliases >>",
    "del alias:sl -Force",
    "Set-Alias -Name al -Value Add-Location",
    "Set-Alias -Name sl -Value Switch-Location",
    "Set-Alias -Name shl -Value Show-Location",
    "Set-Alias -Name ol -Value Open-Location",
    "Set-Alias -Name rl -Value Remove-Location",
    "Set-Alias -Name cl -Value Clear-Locations",
    "Set-Alias -Name svl -Value Save-Locations",
    "Set-Alias -Name ll -Value Load-Locations",
    "# Location Stack Aliases <<"
)

if (Select-String 'Location Stack ' -Path $profile) {

    $confirmation = Read-Host 'Location Stack already installed. Overwrite? (y/n)'

    if ($confirmation -eq 'y') {

        $skip = $false

        foreach ($line in $profileContent) {
            if ($line -eq '# Location Stack Functions >>') {
                $skip = $true
            }

            if (!$skip) {
                if ($line.trim() -notin $aliases) {
                    $profileContent_New += $line
                }
            }

            if ($line -eq '# Location Stack Functions<<') {
                $skip = $false
            }
        }

    } else {
        if ($confirmation -eq 'n') {
            exit
        } else {
            throw 'Invalid input. "y" or "n" expected.'
        }
    }
} else {
    $profileContent_New = $profileContent
}

$scriptContent = cat $MyInvocation.MyCommand.Source -Encoding Ascii
$install_LocationStack = @()

foreach ($line in $scriptContent) {
    if ($line -eq '# Install Location Stack') {
        break
    }

    $install_LocationStack += $line
}

$profileContent_New = $install_LocationStack + $profileContent_New

if ($profileContent_New[$profileContent_New.Length - 1].Trim().Length -ne 0) {
    $profileContent_New += ""
}
$aliases | %{$profileContent_New += $_}

$profileContent_New | Out-File $profile -Encoding ascii -Force

Write-Host "Location Stack functions succesfully added to PowerShell profile." -ForegroundColor DarkGreen
Write-Host "Open new PowerShell console window to use." -ForeGroundColor DarkGreen