Param(
  [string]$sourcePackageName,
  [string]$targetPackageName,
  [switch]$doNotZipUp
)


function Use-RunAs #elevates script permissions to admininistrator
{    
    # Check if script is running as Adminstrator and if not use RunAs 
    # Use Check Switch to check if admin 
     
    param([Switch]$Check) 
     
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent() 
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
         
    if ($Check) { return $IsAdmin }     
 
    if ($MyInvocation.ScriptName -ne "") 
    {  
        if (-not $IsAdmin)  
        {  
            try 
            {  
                $arg = "-file `"$($MyInvocation.ScriptName)`"" 
                Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $arg -ErrorAction 'stop'  
            } 
            catch 
            { 
                Write-Warning "Error - Failed to restart script with runas"  
                break               
            } 
            exit # Quit this session of powershell 
        }
		else
		{
			write-output "Running as administrator...OK"
		}
    }  
    else  
    {  
        Write-Warning "Error - Script must be saved as a .ps1 file first"  
        break  
    }  
} 

function Wait-Anykey([string]$message) #displays message (optional) and awaits any key stroke
{
    if ($message)
    {
        Write-Output "`n$message"
    }
    
    Write-Host "Press any key..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Exit-OnError ([string]$message) #displays error message, stops logging and exits script
{
    $errorMessage = "Error - " + $message
    Write-Host "`n$errorMessage" -ForegroundColor Red
    Write-Host "The script will NOT proceed" -ForegroundColor Yellow
    Stop-Transcript
    if (!$silent) {Wait-Anykey}
    exit
}

function Get-ScriptDirectory #returns directory from where this script runs
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value;
    if($Invocation.PSScriptRoot)
    {
        $Invocation.PSScriptRoot;
    }
    Elseif($Invocation.MyCommand.Path)
    {
        Split-Path $Invocation.MyCommand.Path
    }
    else
    {
        $Invocation.InvocationName.Substring(0,$Invocation.InvocationName.LastIndexOf("\"));
    }
}

function Prompt-YesNo ([string]$message,[string]$question) #displays promt message and awaits user yes/no answer
{
    $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
    $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
    
    if ($decision -eq 0)
    {
        return $true
    } else {
        return $false
    } 
}

function Read-RegistryKey([string]$path,[string]$subkey) #returns value of specified Registry subkey
{
    Try
    {
        $keyValue = Get-ItemProperty $path  -ErrorAction Stop | Select-Object -ExpandProperty $subkey -ErrorAction Stop
        return $keyValue
    }
    Catch
    {
        return $null
    }
}

function Unzip-Packages 
{
    Add-Type -AssemblyName "system.io.compression.filesystem"
        
    #deleting any directories that match packages names if any
    Write-Output "`n  Cleaning $currentdir..."
    
    Try 
    {
        if (Test-Path $sourceDir)
        {
            Write-Host "     deleting: $sourceDir"
            Remove-Item $sourceDir -Recurse -Force -ErrorAction Stop
        }
    }
    Catch
    {
        Exit-OnError -message "Can not remove $sourceDir. Please remove this directory manually."
    }

    Try 
    {
        if (Test-Path $targetDir)
        {
            Write-Host "     deleting: $targetDir"
            Remove-Item $targetDir -Recurse -Force -ErrorAction Stop
        }
    }
    Catch
    {
        Exit-OnError -message "Can not remove $targetDir. Please remove this directory manually."
    }

    Write-Host "  ok"        
        
    #unzipping packages
    Write-Output "`n  Unzipping packages..."

    
    $zipfilePath = $currentdir + "\" + $sourcePackageName
    Write-Host "     $zipfilePath"
    Try
    {
        [io.compression.zipfile]::ExtractToDirectory($zipfilepath,$sourceDir)
    }
    Catch
    {   
        Exit-OnError -message "Failed to unzip $zipfilePath"
    }

    
    $zipfilePath = $currentdir + "\" + $targetPackageName
    Write-Host "     $zipfilePath"
    Try
    {
        [io.compression.zipfile]::ExtractToDirectory($zipfilepath,$targetDir)
    }
    Catch
    {   
        Exit-OnError -message "Failed to unzip $zipfilePath"
    }

    Write-Host "  ok"
            
    Write-Host "Complete." -ForegroundColor DarkGreen
}

function Display-Parameters #prints out current run parameters
{
    Write-Output "`n============================="
    Write-Output "repackaging for: $Product`n"
    Write-Output "Current parameters:"
    Write-Output "-----------------------------"
    Write-Output "Current directory:`t$currentdir"
    Write-Output "Log file: `t`t$logfileName"
    Write-Output "Source package:`t`t$sourcePackageName"
    Write-Output "Hotix package:`t`t$targetPackageName"
    Write-Output "=============================`n"
}

function Update-Hotfix
{    
    foreach ($file in (Get-ChildItem -Path "$targetDir\$targetDirNameOnly\AtHocENS" -File -Recurse))
    {
        $targetPath = Convert-Path $file.Pspath
        $sourcePath = $sourceDir + "\AtHocENS" + ([regex]::Match($targetPath, '(?<=AtHocENS).*').Value)
        $isExcepted = $false

        #checks if filename is not in exception list
        foreach ($name in $exceptionList)
        {
            if ($name -eq $file.Name)
            {
                $isExcepted = $true
            }
        }

        if ($isExcepted -eq $false)
        {
            Try
            {
                Write-Host "     copying $sourcePath ==> $targetPath"
                Copy-Item -Path $sourcePath -Destination $targetPath -Force -ErrorAction Stop
            }
            Catch
            {
                Write-Host "Warning: unable to replace $targetPath" -ForegroundColor Yellow
            }
        }        
    }

    Write-Host "Complete." -ForegroundColor DarkGreen
}

function Repackage-Hotfix
{
    Add-Type -AssemblyName "system.io.compression.filesystem"
    
    Remove-Item -Path "$currentdir\$targetPackageName" -Force -ErrorAction Stop -WarningAction Stop

    $zipDir = $targetDir
    $zipFile = $currentdir + "\" + $targetPackageName

    Try
    {
        [System.IO.Compression.ZipFile]::CreateFromDirectory($zipDir,$zipFile)
    }
    Catch
    {   
        Exit-OnError -message "Failed to create zipfile: $currentdir\$targetPackageName"
    }

    Write-Host "Complete." -ForegroundColor DarkGreen
}


#### === BEGIN ===

#Makes sure that script is running as administrator
Use-RunAs

#Script Parameters
#-------------------------------------------------
$Product = "IWSAlerts"
$currentdir = Get-ScriptDirectory
$logfileName = "repackageHotfix.log"
$exceptionList = "deployCOMs.bat","undeployCOMs.bat","run.bat","gacutil.exe.config","gacutlrc.dll"
if (!$sourcePackageName) {$sourcePackageName = "platform_build_full.zip"}
if (!$targetPackageName) {$targetPackageName = "CHF3(6.1.8.87CP1).zip"}
$sourceDir = $currentdir + "\" + ([regex]::Match($sourcePackageName, '.*(?=\.zip)').Value)
$targetDirNameOnly = ([regex]::Match($targetPackageName, '.*(?=\.zip)').Value)
$targetDir = $currentdir + "\" + $targetDirNameOnly
#-------------------------------------------------

#Starts log
Try
{
    Start-Transcript -path ($currentdir + "\" + $logfileName) -Force -ErrorAction Stop
}
Catch
{
    $errorMessage = "Error - Unable to start log. Please check if InstallHotfix.log file present in $currentdir. Delete if found"
    Write-Host "`n$errorMessage" -ForegroundColor Red
    Write-Host "The script will NOT proceed" -ForegroundColor Yellow
    if (!$silent) {Wait-Anykey}
    exit
}

#Prints out current parameters set
Display-Parameters

#extracts packages content
Write-Host "`nUnzipping packages in $currentdir" -ForegroundColor Cyan
Unzip-Packages

#replaces all files in hotfix with those from build package
Write-Host "`nReplacing files in $targetPackageName`n" -ForegroundColor Cyan
Update-Hotfix

#repackages hotfix
if (!$doNotZipUp)
{
    Write-Host "`nRepackaging $targetPackageName`n" -ForegroundColor Cyan
    Repackage-Hotfix
}

Write-Host "`n======================================"
Wait-Anykey -message "FINISHED"
Stop-Transcript
exit

### === END ===