<#
.SYNOPSIS
	Installs IWS hotfix from supplied .zip file.
.DESCRIPTION
	This script is intended to be used with the hotfix package that it is shipped with.

	This script uses Registry to determine IWS installation location and database connection string, when running on Application server (or App + DB combo box). If it runs on machine where only database is installed, DB user, password (and instance, if not default: ".") must be supplied as input parameters.

	The script uses SQLCMD command line utility to execute SQL queries. This utility comes by default with MSSQL server, but might not be installed on Application-only server. In this case user must install SQLCMD manually before running the script, or run script twice: first on Application server (with -Server Application parameter), then on Database server (with -Server Database -DbUser <user> -DbPassword <"password"> parameters).
.PARAMETER	Server
	Alias: 'Target'
 Specifies target server (Application, Database) to apply patch to.
 Accepted values: 'Application','Database','CustomScript','All'
.PARAMETER	StopAppForDatabaseUpgrade
    Alias: 'StopApp'
 Indicates that Application server should be stopped for for duration of both Application and Database upgrade. By default, Application server will only stop for it's own upgrade and then start again before Database upgrade.
 This will only work if running on Application Server. If you upgrade Database server individually, please stop Application server manually.
.PARAMETER	DbUser
	Specifies Database connection user. If not specified, attempts to read username from IWS OleDbConnectionString in Registry (this only works if running from Application server, because registry entriy on Database server lacks OleDbConnectionString. This parameter is mandatory, if running locally from Database server).
.PARAMETER	DbPassword
	Specifies Database connection password (in quotes). If not specified, attempts to read username from IWS OleDbConnectionString in Registry (this only works if running from Application server, because registry entriy on Database server lacks OleDbConnectionString. This parameter is mandatory, if running locally from Database server).
.PARAMETER	DbInstance
	Specifies Database server(\instance). If not specified, attempts to read username from IWS OleDbConnectionString in Registry (this only works if running from Application server). If not found, tries to use <localhost\defaultInstance> (".")
.PARAMETER	Silent
	Indicates that all the prompts should be supressed, allowing script to run without user interaction.
.PARAMETER	NoCustomScript
	Prevents execution of CustomScript if such script is packaged into hotfix (useful if user wants to run CustomScript manually or on specific machines only).
Does nothing if no CustomScript is packaged.
.PARAMETER	Rollback
	Switches script execution to rollback mode.
.EXAMPLE
    .\Install.ps1

    Applies patch to both Application server and Database server with default parameters. (Runs on Application Server machine or combo-box (App + DB on single machine)).
 SQL command line utility (SQLCMD) and it's prerequisite (MSODBCSQL) must be installed on Application server. Database instance, user and password will be read from IWS installation entry in Registry.
.EXAMPLE
    .\Install.ps1 -Server Application

    Applies patch to Application server with default parameters. (Runs on Application Server machine or combo-box (App + DB on single machine)).
.EXAMPLE
    .\Install.ps1 -Server Database -DbUser "athoc\user" -DbPassword "pass123" -DbInstance "."

    Advanced. Refer to eWiki page for more info.
    Applies patch to local Database server to default instance. (Runs on Database Server machine). Append "." with instance name if not default like this: -DbInstance ".\YorInstance"
.EXAMPLE
    .\Install.ps1 -Rollback

    Executes Rollback for both Application server and Database server with default parameters. (Runs on Application Server machine or combo-box (App + DB on single machine)).
 SQL command line utility (SQLCMD) and it's prerequisite (MSODBCSQL) must be installed on Application server. Database instance, user and password will be read from IWS installation entry in Registry.
.EXAMPLE
    .\Install.ps1 -Server Application -Rollback

    Executes Rollback for Application server with default parameters. (Runs on Application Server machine or combo-box (App + DB on single machine)).
.EXAMPLE
    .\Install.ps1 -Server Database -DbUser "athoc\user" -DbPassword "pass123" -DbInstance "." -Rollback

    Advanced. Refer to eWiki page for more info.
    Executes Rollback for local Database server for default instance. (Runs on Database Server machine). Append "." with instance name if not default, like this: -DbInstance ".\YorInstance"
.LINK
	For more information, please follow the link:
 https://ewiki.athoc.com/display/BR/Install.ps1
.NOTES
  2016 Pavel Stsefanovich
#>


[cmdletbinding(HelpUri = "https://ewiki.athoc.com/display/BR/Install.ps1")]
Param (
    [parameter(HelpMessage="Please specify target server: <Application>, <Database> or <All>")]
    [ValidateSet("Application","Database","CustomScript","All")]
    [Alias('Target')]
    [string]$Server = "All",

    [parameter()]
    [Alias('StopApp')]
    [switch]$StopAppForDatabaseUpgrade,

    [parameter()]
    [string]$DbUser,

    [parameter()]
    [string]$DbPassword,

    [parameter()]
    [Alias('DbServer')]
    [string]$DbInstance,

    [parameter()]
    [switch]$Silent,

    [parameter()]
    [switch]$NoCustomScript,

    [parameter()]
    [switch]$Rollback
)


function Use-RunAs { #elevates script permissions to admininistrator

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

function Create-Logfile {

    $date = (Get-Date -Format 'M/dd/yyyy  HH:mm:ss').ToString()
	$fullComputerName = "$env:COMPUTERNAME.$env:USERDNSDOMAIN"
    $logStartline = @("$date",
					"$fullComputerName",
					"$scriptDirectory",
                    "-------------------",
                    "Input parameters:",
                    " ",
                    "HotfixPackageName:`t`t$hotfixPackageName",
                    "Server:`t`t`t`t$server",
                    "StopAppForDatabaseUpgrade:`t$StopAppForDatabaseUpgrade",
                    "DbInstance:`t`t`t$DbInstance",
                    "DbUser:`t`t`t`t$DbUser",
                    "Silent:`t`t`t`t$Silent",
                    "NoCustomScript:`t`t$NoCustomScript",
                    "Rollback:`t`t`t$Rollback",
                    "-------------------",
                    "`n")

    Remove-Item ".\$errorFileName" -Force -ErrorAction SilentlyContinue

    if (Test-Path ".\$logFileName") {

        Try
        {
            Get-ChildItem $logFileName* | Sort-Object -Property Name -Descending | %{Rename-Item $_ ($_.Name + "-bkp")}
        }
        Catch
        {
            Write-Output "`n$date`t!ERROR: Can't backup old log file: `"$logFileName`"" | Out-File ".\$exitErrorFileName" -Force
        }
    }

    Try
    {
        New-Item $logFileName -ItemType File -Force -ErrorAction Stop | Out-Null
    }
    Catch
    {
        Write-Output "`n$date`t!ERROR: Can't create log file `"$logFileName`". Please check if file already exists or locked" | Out-File ".\$exitErrorFileName" -Force
        if (!$Silent) {Wait-Anykey}
    }

    Add-Content $logFileName -Value $logStartline
    Write-Output "`n"
    $logStartline
    sleep -s 1
}

function Write-Log ($message,[switch]$error,[switch]$warning,[switch]$detailed,[switch]$flat,[switch]$noconsole) {

    if ($message) {

        if (!$noconsole) {
            if ($message.GetType().name -eq 'String' -and !($error) -and !($warning)) {
                if ($detailed) {Write-Host "`t$message" -ForegroundColor DarkGray} else {Write-Host $message}
            }
        }

        $date = (Get-Date -Format 'M/dd/yyyy  HH:mm:ss').ToString()

        if ($error) {
            if (!$noconsole) {Write-Host "`t! ERROR: $message" -ForegroundColor Red}
            Add-Content $logFileName -Value "$date`t! ERROR:"
            Add-Content $logFileName -Value $message
            Add-Content $logFileName -Value "`t`t`t--- End of error message ---"
            $script:errorLevel++
        } elseif ($warning) {
            if (!$noconsole) {Write-Host "`t! Warning: $message" -ForegroundColor Yellow}
            Add-Content $logFileName -Value "$date`t! Warning:"
            Add-Content $logFileName -Value "$message"
            Add-Content $logFileName -Value "`t`t`t--- End of warning message ---"
        } elseif ($flat) {
            Add-Content $logFileName -Value $message
        } elseif ($detailed) {
            Add-Content $logFileName -Value "$date`t`t$message"
        } else {Add-Content $logFileName -Value "$date`t$message" -Force }
    }

    Out-Null
}

function Close-Log {

    $date = (Get-Date -Format 'M/dd/yyyy  HH:mm:ss').ToString()
    $logFinishtline = @("`n",
                    "-------------------",
                    "$date",
                    "END")

    Add-Content $logFileName -Value $logFinishtline
    Write-Output $logFinishtline

    if ($errorLevel -ne 0) {

        "Finished with some errors!" | Tee-Object $logFileName -Append
        "ErrorLevel: $Script:errorLevel" | Tee-Object $logFileName -Append

    } else {

        $outMessage = "Finished Successfully`n"
        Add-Content $logFileName -Value $outMessage
        Write-Output $outMessage
    }

    sleep -s 3
}

function Exit-OnError ([string]$message,[switch]$append) { #displays error message, stops logging and exits script

    Write-Log $message -error
    Write-Host "The script will NOT proceed" -ForegroundColor Yellow
    if ($append) {$message | Out-File ".\$errorFileName" -Force -Append}
        else {$message | Out-File ".\$errorFileName" -Force}
    "ErrorLevel: $script:errorLevel" | Out-File ".\$errorFileName" -Force -Append
    if (!$Silent) {Wait-Anykey}
    exit 1
}

function Wait-Anykey ([string]$message) { #displays message (optional) and awaits any key stroke

    if (!$Silent) {
        if ($message)
        {
            Write-Log "$message"
        }
        Write-Log "Press any key..."
        $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

function Prompt-YesNo ([string]$message,[string]$question) { #displays promt message and awaits user yes/no answer

    $result = $true
    Write-Log $message -noconsole | Out-Null

    if (!$Silent) {
        Write-Log $question -noconsole | Out-Null
        $choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
        $choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
        $decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)

        if ($decision -eq 0) {Write-Log "<Yes>" | Out-Null} else {$result = $false; Write-Log "< No >" | Out-Null}
    }

    Out-Null
    return $result
}

function Read-Properties ($propertiesFilePath) {

    $properties = Get-Content $propertiesFilePath
    $script:deleteList = @()
    $script:gatewayInstallerList = @()
    [string]$script:customScript
    [string]$script:customArgs
	[string]$script:customScriptRollback
    [string]$script:customArgsRollback

    foreach ($line in $properties) {

        if (!$script:Rollback) {
            $lineDelete = ([regex]::Match($line, '(?<=DELETE\:\s).*$').Value)

            if ($lineDelete) {$script:deleteList += $lineDelete; Write-Verbose ("DELETE: " + $lineDelete)}
        }

        $lineGateway = ([regex]::Match($line, '(?<=GATEWAY\:\s).*$').Value)
        $lineCscript = ([regex]::Match($line, '(?<=C\.SCRIPT\:\s).*$').Value)
        $lineCargs = ([regex]::Match($line, '(?<=C\.ARGS\:\s).*$').Value)
        $lineCscriptRlb = ([regex]::Match($line, '(?<=C\.SCRIPT\.ROLLBACK\:\s).*$').Value)
        $lineCargsRlb = ([regex]::Match($line, '(?<=C\.ARGS\.ROLLBACK\:\s).*$').Value)

        if ($lineGateway) {$script:gatewayInstallerList += $lineGateway; Write-Verbose ("GATEWAY: " + $lineGateway)}

        if ($lineCscript) {
            if ($silent -and !$NoCustomScript) {
                Start-Application
                Exit-OnError "Silent mode does not allow execution of CustomScript. Please run this script again interactively (no -silent switch), or append -NoCustomScript parameter to disable CustomScript execution"
            }
            $script:customScript = $lineCscript; Write-Verbose ("C.SCRIPT: " + $lineCscript)
        }
        if ($lineCargs) {$script:customArgs = $lineCargs; Write-Verbose ("C.ARGS: " + $lineCargs)}

        if ($lineCscriptRlb) {
            if ($silent -and !$NoCustomScript) {
                Start-Application
                Exit-OnError "Silent mode does not allow execution of CustomScript. Please run this script again interactively (no -silent switch), or append -NoCustomScript parameter to disable CustomScript execution"
            }
            $script:customScriptRollback = $lineCscriptRlb; Write-Verbose ("C.SCRIPT.ROLLBACK: " + $lineCscriptRlb)
        }
        if ($lineCargsRlb) {$script:customArgsRollback = $lineCargsRlb; Write-Verbose ("C.ARGS.ROLLBACK: " + $lineCargsRlb)}
    }
}

function Stop-Application {

    Write-Log "Stopping Application server..."

    Write-Log "IIS" -detailed | Out-Null
    Try {iisreset -stop | Tee-Object -Variable iisout} Catch {Exit-OnError $_}
    Write-Log $iisout -flat | Out-Null

    Write-Log "AppFabric" -detailed | Out-Null
    Get-Service "AppFabric*" | Stop-Service -ErrorAction Stop -ErrorVariable err6 -WarningAction SilentlyContinue
    if ($err6) {Exit-OnError $err6}

    Write-Log "AtHoc tools" -detailed | Out-Null
    Get-Process "AtHoc*" | Stop-Process -Force -ErrorAction Stop -ErrorVariable err7 -WarningAction SilentlyContinue
    if ($err7) {Exit-OnError $err7}
}

function Start-Application {

    Write-Log "Starting Application server..."

    Write-Log "AppFabric" -detailed | Out-Null
    Get-Service "AppFabric*" | Start-Service -ErrorAction Stop -ErrorVariable err8 -WarningAction SilentlyContinue
    if ($err8) {Exit-OnError $err8}

    Write-Log "IIS" -detailed | Out-Null
    Try {iisreset -start | Tee-Object -Variable iisout} Catch {Exit-OnError $_}
    Write-Log $iisout -flat | Out-Null
}

function Run-Process ([string]$processName,[string]$arguments,[string]$processWorkingDirectory) {

    [hashtable]$output = @{}

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "$processName"
    $pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "$arguments"
    if ($processWorkingDirectory) {
      $pinfo.WorkingDirectory = $processWorkingDirectory
    }
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    Try {$p.Start()}
    Catch {Exit-OnError $_": line:342"}
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    $output.stdout = $stdout
    $output.stderr = $stderr
    $output.errcode = $p.ExitCode

    Write-Verbose ("stdout: " +$stdout)
    Write-Verbose ("stderr: " +$stderr)
    Write-Verbose ("errcode: " +$p.ExitCode)

    return $output
}

function Register-COMs ($comDir,[switch]$unregister) {

    $comResult = $true

    if ($unregister) {"unCOM::start" | Out-File $RollbackProperties -Append}
    else {"COM::start" | Out-File $RollbackProperties -Append}

    foreach ($assembly in (Get-ChildItem $comDir -File -Filter '*.dll' | ?{$_.Name -notlike 'aspSmartUploadUtil*'})) {

        $assemblyName = $assembly.BaseName
        $assemblyFullPath = $assembly.FullName

        if ($unregister) {
            Write-Log "removing: $assemblyFullPath" -detailed | Out-Null
            Write-Verbose "regsvr32 /u `"$assemblyFullPath`""
            $comOutput = Run-Process regsvr32 -arguments "/u /s `"$assemblyFullPath`""
            if ($comOutput.errcode -gt 0) {Write-Log "WARNING: Unregistering failed for: $assemblyName"}

		} else {
            Write-Log "installing: $assemblyFullPath" -detailed | Out-Null
            Write-Verbose "regsvr32 `"$assemblyFullPath`""
            $comOutput = Run-Process regsvr32 -arguments "/s `"$assemblyFullPath`""
            if ($comOutput.errcode -gt 0) {Write-Log "Registering failed for: $assemblyName" -error}
        }

        Write-Log $comOutput.stdout -flat | Out-Null

        if (!$unregister -and $comOutput.errcode -gt 0) {$comResult = $false}
    }

    if ($unregister) {"unCOM::$comResult" | Out-File $RollbackProperties -Append}
    else {"COM::$comResult" | Out-File $RollbackProperties -Append}

    return $comResult
}

function Register-GAC ($gacDir,[switch]$unregister) {

    $gacResult = $true
    if ($unregister) {"unGAC::start" | Out-File $RollbackProperties -Append}
    else {"GAC::start" | Out-File $RollbackProperties -Append}

    foreach ($assembly in (Get-ChildItem $gacDir -File -Filter '*.dll' | ?{$_.Name -notlike 'gacut*'})) {

        $assemblyFullPath = $iwsInstallationDirectory + ([regex]::Match($assembly.FullName, '(?<=AtHocENS).*').Value)

        if ($unregister) {
            $assemblyName = $assembly.BaseName
            "GACitem=$assemblyFullPath" | Out-File $RollbackProperties -Append
            Write-Log "removing: $assemblyName" -detailed | Out-Null
            $gacOutput = Run-Process $gacUtil -arguments "/uf $assemblyName"

		} else {
            Write-Verbose "%assemblyFullPath% $assemblyFullPath"
            Write-Log "installing: $assemblyFullPath" -detailed | Out-Null
            $gacOutput = Run-Process $gacUtil -arguments "/if `"$assemblyFullPath`""
        }

        Write-Log $gacOutput.stdout -flat | Out-Null

        if ($gacOutput.errcode -gt 0) {$gacResult = $false}
        elseif ($unregister) {
            if ([int]([regex]::Match($gacOutput.stdout, '(?<=uninstalled\s\=\s).*\n').Value) -eq 0) {
                if ($gacOutput.stdout -notlike '*No assemblies found matching:*') {
                    Write-Log "Unregistering unsuccessful: $assemblyName`n" -error | Out-Null
                    $gacResult = $false
                }
            }
        }
    }

    if ($unregister) {"unGAC::$gacResult" | Out-File $RollbackProperties -Append}
    else {"GAC::$gacResult" | Out-File $RollbackProperties -Append}

    return $gacResult
}

function Remove-WinInstallerRef ($gacDir) {

    $winInstallerResult = $true
	foreach ($assembly in (Get-ChildItem $gacDir -File -Filter '*.dll' | ?{$_.Name -notlike 'gacut*'})) {
        $assemblyName = $assembly.BaseName
        Write-Verbose "%assemblyName% $assemblyName"
		Try {
	        foreach ($item in (Get-Item -Path Registry::HKLM\Software\Classes\Installer\Assemblies\Global | Select-Object -ExpandProperty property)) {
				if ($item -like "*$assemblyName*") {Remove-ItemProperty Registry::HKLM\Software\Classes\Installer\Assemblies\Global -Name $item }
			}
		} Catch {
            $winInstallerResult = $false
            Write-Log $_ -error | Out-Null
		}
	}

    return $winInstallerResult
}

function Remove-Deprecated ($list) {
    "DEL::start" | Out-File $RollbackProperties -Append
    $dprcResult = $true
    foreach ($item in $list) {
        $itemPath = $iwsInstallationDirectory + ([regex]::Match($item, '(?<=AtHocENS).*').Value)
        Write-Log "deleting: $itemPath" -detailed | Out-Null
        if (Test-Path $itemPath) {
            Try {Remove-Item $itemPath -Recurse -Force -ErrorAction Stop}
            Catch {$dprcResult = $false; Write-Log $_ -error | Out-Null}
        } else {Write-Log "Not found. Must have been already deleted" -detailed | Out-Null}
    }

    "DEL::$dprcResult" | Out-File $RollbackProperties -Append
    return $dprcResult
}

function Run-GatewayInstaller ($list) {
    "GATEWAY::start" | Out-File $RollbackProperties -Append
    $gatewayResult = $true
    $gatewayInstallerLogfile = "C:\GatewayInstaller.log"
    Try {if (Test-Path $gatewayInstallerLogfile) {Remove-Item $gatewayInstallerLogfile -Force -ErrorAction Stop -ErrorVariable err12}}
    Catch {$gatewayResult = $false}

    if ($gatewayResult) {
        $gatewayInstaller = $iwsInstallationDirectory + "\ServerObjects\Tools\GatewayInstaller\AtHoc.Applications.Tools.InstallPackage.GatewayInstaller.exe"
        Write-Verbose "%gatewayInstaller% $gatewayInstaller"
        [int]$logLine = 0
        foreach ($item in $list) {
            Write-Log "enabling: $item" -detailed | Out-Null
            $gatewayOut = Run-Process $gatewayInstaller -arguments "`"$item`""
            Write-Log $gatewayOut.stdout -flat | Out-Null
            $logContent = Get-Content $gatewayInstallerLogfile
            Write-Verbose "%logLine% $logLine"
            Write-Verbose ("%logContent[$logLine + 1]%" + $logContent[$logLine + 1])
            if (($gatewayOut.errcode -gt 0) -or ($logContent[$logLine + 1] -ne ("InstallPackages : Installing gateway: " + $item))) {
                Write-Log "Installing gateway unsuccessful: $item" -warning | Out-Null; $gatewayResult = $false
            } else {
                "GATEWAYitem=$item"
            }
            $logLine = $logContent.Length
        }
    }

    "GATEWAY::$gatewayResult" | Out-File $RollbackProperties -Append
    return $gatewayResult
}

function Execute-SqlFiles ($filesList) {

    #(ps) "SQL::start" | Out-File $RollbackProperties -Append
    $sqlResult = $true

    foreach ($file in $filesList) {

        $fpath = $file.FullName
        $sqlArgLine = "-U $DbUser -P $DbPassword -S $DbInstance -I -b -x -l 30 -V 1 -i `"$fpath`""
        Write-Verbose "running: sqlcmd -U $DbUser -P ***** -S $DbInstance -I -b -x -l 30 -V 1 -i `"$fpath`""
        Write-Log "running: $fpath" -detailed
        #(ps) "SQLitem=$fpath" | Out-File $RollbackProperties -Append
        $result = Run-Process sqlcmd -arguments $sqlArgLine
        if ($result.errcode -gt 0) {
            $sqlResult = $false
            Write-Log $result.stdout | Out-Null
            "SQL::$sqlResult" | Out-File $RollbackProperties -Append
            Exit-OnError $result.stderr
        }
        else {Write-Log $result.stdout -flat | Out-Null}
    }

    #(ps) "SQL::$sqlResult" | Out-File $RollbackProperties -Append
    Out-Null
}

function Validate-Rollbackfile ($file) {

    $validationResult = "invalid"
    $properties = Get-Content $file

    $script:bkpFiles = @()
    $script:bkpDelFiles = @()
    $script:bkpNewFiles = @()
    [boolean]$script:bkpComs = $false
    [boolean]$script:bkpGac = $false

    foreach ($line in $properties) {

        if (([regex]::Match($line, '^unCOM\:\:').Value) -or ([regex]::Match($line, '^COM\:\:').Value)) {
            $script:bkpComs = $true
            Write-Verbose ("%bkpComs% $bkpComs")
        }

        if (([regex]::Match($line, '^unGAC\:\:').Value) -or ([regex]::Match($line, '^GAC\:\:').Value)) {
            $script:bkpGac = $true
            Write-Verbose ("%bkpGac% $bkpGac")
        }

        $lineBkp = ([regex]::Match($line, '(?<=BKPitem\=).*$').Value)
        if ($lineBkp) {
            $script:bkpFiles += $lineBkp
            Write-Verbose ("%lineBkp% $lineBkp")
        }

        $lineBkpDel = ([regex]::Match($line, '(?<=BKPDELitem\=).*$').Value)
        if ($lineBkpDel) {
            $script:bkpDelFiles += $lineBkpDel
            Write-Verbose ("%lineBkpDel% $lineBkpDel")
        }

        $lineBkpNew = ([regex]::Match($line, '(?<=BKPNEWitem\=).*$').Value)
        if ($lineBkpNew) {
            $script:bkpNewFiles += $lineBkpNew
            Write-Verbose ("%lineBkpNew% $lineBkpNew")
        }

        $lineFailure = ([regex]::Match($line, '(?<=\:\:)False$').Value)
        if ($lineFailure) {
            $validationResult = "failed"
        }
    }

    if ($bkpComs -or $bkpGac -or $bkpFiles -or $bkpDelFiles -or $bkpNewFiles) {
        if ($validationResult -ne "failed") {
            $validationResult = "successful"
        }
    }

    Out-Null
    Write-verbose "<Validate-Rollbackfile> $validationResult"
    return $validationResult
}

function Validate-CsRollbackfile ($file) {

	$validationResult = "invalid"
	$properties = Get-Content $file
	
	foreach ($line in $properties) {	
		$lineFailure = ([regex]::Match($line, '(?<=\:\:)False$').Value)
		$lineSuccess = ([regex]::Match($line, '(?<=\:\:)True$').Value)		
	}
	
	if ($lineFailure -and !$lineSuccess) {
		$validationResult = "failed"
	} elseif ($lineSuccess -and !$lineFailure) {
		$validationResult = "successful"
	}
	
	Out-Null
    Write-verbose "<Validate-CsRollbackfile> $validationResult"
	return $validationResult
}


#=== BEGIN ===

[int]$errorLevel = 0
if ($Rollback) {
    $logFileName = "_Rollback.log"
    $errorFileName = "_ExitErrorRollback.log"
} else {
    $logFileName = "_Install.log"
    $errorFileName = "_ExitError.log"
}
$runApp = $true
$runCS = $true
$runDB = $true
$PropertiesFileName = "Install.properties"
$scriptDirectory = $PSScriptRoot
$backupDirectory = "$scriptDirectory\_Backup"
$RollbackPropertiesFileName = "_Rollback.properties"
$CustomScriptRlbPropFileName = "_CustomScript.Rollback.properties"
$RollbackProperties = "$scriptDirectory\$RollbackPropertiesFileName"
$CustomScriptRlbProperties = "$scriptDirectory\$CustomScriptRlbPropFileName"
Write-Verbose "%scriptDirectory% $scriptDirectory"
if (!(Use-RunAs -Check)) {Exit-OnError "Please run script as administrator"}
if (Get-ChildItem "$scriptDirectory\packageinfo*" -File) {
    $packageInfoFilePath = (Get-ChildItem "$scriptDirectory\packageinfo*" -File).FullName
    $hotfixPackageName = (Get-ChildItem "$scriptDirectory\packageinfo*" -File).BaseName.Substring(12)
    $hotfixTargetVersion = ([regex]::Match($hotfixPackageName, '(?<=\()\d\.\d\.\d\..*(?=\))').Value)
    $hotfixID = [regex]::Match($hotfixPackageName, 'HF\-.*(?=\(\d\.\d\.\d\..*\))').Value
    $packageInfo = Get-Content $packageInfoFilePath}
else {Exit-OnError "Can't find 'packageinfo-' file in $scriptDirectory. Hotfix package may be incomplete"}
$iwsInstallationRegistry = "HKLM:\SOFTWARE\Wow6432Node\AtHocServer"
Write-Verbose "%packageInfoFilePath% $packageInfoFilePath"
Write-Verbose "%hotfixPackageName% $hotfixPackageName"
Write-Verbose "%hotfixTargetVersion% $hotfixTargetVersion"
Write-Verbose "%hotfixID% $hotfixID"
Write-Verbose "%iwsInstallationRegistry% $iwsInstallationRegistry"
Write-Verbose "%RollbackProperties% $RollbackProperties"

Create-Logfile

#- checks if IWS installed (Application server only)
if (($server.ToLower() -eq"application".ToLower()) -or ($server.ToLower() -eq"all".ToLower())) {
	if (Test-Path "$iwsInstallationRegistry\Install") {
        $iwsInstallationDirectory = (Get-Item "$iwsInstallationRegistry\Install").GetValue("AppLoc").TrimEnd('\')
        $IWSversionApp = (Get-Item "$iwsInstallationRegistry\Install").GetValue("Version").TrimEnd('\')
        Write-Verbose "%iwsInstallationDirectory% $iwsInstallationDirectory"
        Write-Verbose "%IWSversionApp% $IWSversionApp"

        if ($hotfixTargetVersion -ne $IWSversionApp) {Exit-OnError "Version mismatch. Hotfix: $hotfixTargetVersion;  Installed App server version: $IWSversionApp; "}
    } else {Exit-OnError "Cant find IWS installation entry in registry: $iwsInstallationRegistry"}
}

#- checks if SCLCMD installed
if (($server.ToLower() -ne "application".ToLower()) -and (Get-Command "sqlcmd" -ErrorAction SilentlyContinue) -eq $null) {
    Write-Log "SQLCMD utility is required but it's not installed. Please install SQLCMD, or run this script to upgrade Application server only (refer to Readme for more info)" -warning
    Wait-Anykey "Powershell must be reopened after SQLCMD installation. Press any key to close this window."
    Stop-Process -Id $PID
}

if ($Rollback) {Write-Log "!! Running in ROLLBACK mode"; sleep -s 2}
else {sleep -s 1}


#=== STOPS APPLICATION SERVER

if ($StopAppForDatabaseUpgrade -and (($server.ToLower() -eq "application".ToLower()) -or ($server.ToLower() -eq "all".ToLower()))) {Stop-Application}


#=== APPLIES APPLICATION SERVER PATCH

if (($server.ToLower() -eq "application".ToLower()) -or ($server.ToLower() -eq "all".ToLower()))
{
    if ($Rollback) {

        #- checks if installation properties file exists
        if (Test-Path "$scriptDirectory\$PropertiesFileName") {Read-Properties "$scriptDirectory\$PropertiesFileName"}
        else {Write-Log "Can't find $PropertiesFileName file in $scriptDirectory. Hotfix package may be incomplete" -warning}

        #- checks if Rollback properties file exists
        if (!(Test-Path $RollbackProperties) -or ((Validate-Rollbackfile $RollbackProperties) -eq "invalid")) {

            Write-Log "No Application server installation record found. Skipping..." -warning
			$runApp = $false
        }

    } else {

        #- checks if installation properties file exists
        if (Test-Path "$scriptDirectory\$PropertiesFileName") {Read-Properties "$scriptDirectory\$PropertiesFileName"}
        else {Exit-OnError "Can't find $PropertiesFileName file in $scriptDirectory. Hotfix package may be incomplete"}

        #- checks if Readme.txt file exists
        if (!(Test-Path "$scriptDirectory\Readme.txt")) {Exit-OnError "Can't find Readme.txt file in $scriptDirectory. Hotfix package may be incomplete"}

        #--- check if Rollback properties file exists
        if (Test-Path $RollbackProperties) {
            $rollbackValidation = Validate-Rollbackfile $RollbackProperties

            if ($rollbackValidation -eq "successful") {
                Write-Log "This hotfix has been already applied successfully to Application server. Skipping..." -warning
                $runApp = $false

            } elseif ($rollbackValidation -eq "failed") {
                Write-Log "Previous attempt to install this hotfix to Application server failed and has not been rolled back." -warning
                if (Prompt-YesNo "You can cancel installation now and then run the script again in Rollback mode to clean up, or you can proceed, but installation to Application server will be skipped." -question "Cancel installation?") {
                    Write-Log "Installation cancelled."
                    exit
                } else {
                    Write-Log "Skipping Application server..." -warning
                    $runApp = $false
                }

            } else {
                Remove-Item $RollbackProperties -Force -ErrorAction Stop
            }
        }
		
		

        if ($runApp) {
            #--- BACKUP

            #- creaing list of files to backup
            $athocEnsRelativeFilepaths = @()

            if (Test-Path "$scriptDirectory\AtHocENS") {
                $filesToCopy = Get-ChildItem "$scriptDirectory\AtHocENS" -Recurse -File
                foreach ($file in $filesToCopy) {
                    $relPath = ([regex]::Match(($file.FullName),'AtHocENS\\.*')).Value
                    $athocEnsRelativeFilepaths += @($relPath)
                    Write-Verbose "%relPath% $relPath"
                }
            }

            if ($deleteList) {foreach ($relPath in $deleteList) {Write-Verbose "%relPath% $relPath"}}

            Write-Verbose "%athocEnsRelativeFilepaths% $athocEnsRelativeFilepaths"
            Write-Verbose "%deleteList% $deleteList"

            if ((($server.ToLower() -eq "application".ToLower()) -or ($Server.ToLower() -eq "all".ToLower())) -and !$athocEnsRelativeFilepaths -and !$deleteList) {
                #Write-Log "Nothing to update on Application server."
                $runApp = $false
            }

            #- backing up
            Write-Verbose "%runApp% $runApp"

            if ($runApp) {
                Write-Log "Backing up files..."
                $backupResult = $true
                Write-Verbose "%backupDirectory% $backupDirectory"

                #- archiving original backup
                if (Test-Path $backupDirectory) {
                    Write-Log "Found backup directory from previous run"

                    if (Test-Path "$backupDirectory-original") {
                        Try {Remove-Item $backupDirectory -Force -Recurse -ErrorAction Stop -ErrorVariable err2}
                        Catch {Exit-OnError $err2}
                    } else {
                        Write-Log "Archiving original backup files..."
                        Try {Rename-Item $backupDirectory -NewName "$backupDirectory-original" -Force -ErrorAction Stop -ErrorVariable err14}
                        Catch {Exit-OnError $err14}
                    }
                }

                #- tries to (re)create backup directory
                Try {New-Item $backupDirectory -ItemType Directory -Force -ErrorAction Stop -ErrorVariable err3 | Out-Null}
                Catch {Exit-OnError $err3}

                #- copies files to be modified to backup directory
                foreach ($item in $athocEnsRelativeFilepaths) {
                    $itemPath = $iwsInstallationDirectory + ([regex]::Match($item, '(?<=AtHocENS).*').Value)
                    if (Test-Path $itemPath) {
                        Write-Log "backing up: $item" -detailed
                        $dirList = ($item | Split-Path).Split('\')
                        $backupItemPath = $backupDirectory
                        foreach ($dir in $dirList) {
                            $backupItemPath += "\$dir"
                            if (!(Test-Path $backupItemPath)) {New-Item $backupItemPath -ItemType Directory -Force | Out-Null}
                        }
                        Try {
                            Write-Verbose ("copying: $itemPath  to  $backupDirectory\$item")
                            Copy-Item $itemPath -Destination "$backupDirectory\$item" -Force -ErrorAction Stop -ErrorVariable err11 | Out-Null
                            "BKPitem=$itemPath" | Out-File $RollbackProperties -Append
                        } Catch {$backupResult = $false; Write-Log $err11 -error}
                    } else {"BKPNEWitem=$itemPath" | Out-File $RollbackProperties -Append}
                }

                #- copies files to be deleted to backup directory
                foreach ($item in $deleteList) {
                    $itemPath = ($iwsInstallationDirectory | Split-Path) + "\$item"
                    if (Test-Path $itemPath) {
                        Write-Log "backing up (delete list): $itemPath" -detailed
                        $dirList = ($item | Split-Path).Split('\')
                        $backupItemPath = $backupDirectory
                        foreach ($dir in $dirList) {
                            $backupItemPath += "\$dir"
                            if (!(Test-Path $backupItemPath)) {New-Item $backupItemPath -ItemType Directory -Force | Out-Null}
                        }
                        Try {
                            Write-Verbose ("copying: $itemPath  to  $backupDirectory\$item")
                            Copy-Item $itemPath -Destination "$backupDirectory\$item" -Force -ErrorAction Stop -ErrorVariable err13 | Out-Null
                            "BKPDELitem=$itemPath" | Out-File $RollbackProperties -Append
                        } Catch {$backupResult = $false; Write-Log $err13 -error}
                    }
                }

                "BKP::$backupResult" | Out-File $RollbackProperties -Append
                if (!$backupResult) {
                    Try {Remove-Item $backupDirectory -Force -Recurse -ErrorAction Stop}
                    Catch {Exit-OnError "Backup failed. Unable to remove $backupDirectory. Please remove manually before attempting to run script again!"}
                    Exit-OnError "Backup failed"
                }
            }
        }
	}

    #--- INSTALLATION

    if ($runApp) {
        Write-Verbose "%runApp% $runApp"
        Write-Log "APPLICATION SERVER UPDATE"

        if (Test-Path "$scriptDirectory\AtHocENS") {

            #- stopping Application server if not stopped already
            if (!$StopAppForDatabaseUpgrade) {Stop-Application}

            #- unregistering old COMs from Registry
            if (!$Rollback -or ($Rollback -and $bkpComs)) {
                $comDirectory = $iwsInstallationDirectory + "\ServerObjects\COMs"
                $comDirectoryHotfix = $scriptDirectory + "\AtHocENS\ServerObjects\COMs"
                Write-Verbose "%comDirectory% $comDirectory"
                Write-Verbose "%comDirectoryHotfix% $comDirectoryHotfix"
                if (Test-Path $comDirectoryHotfix) {
                    $isComs = $true
                    Write-Verbose "%isComs% $isComs"
                    Write-Log "Unregistering COMs..."
                    if (!(Register-COMs $comDirectory -unregister)) {Exit-OnError "Unregistering COMs failed"}
                    #(ps) this is redundant because unregistering does not return fail (Register-Coms)
                }
            }

            #- unregistering old assemblies from GAC
            if (!$Rollback -or ($Rollback -and $bkpGac)) {
                $gacDirectory = $scriptDirectory + "\AtHocENS\ServerObjects\DotNet"
                $gacUtil = $scriptDirectory + "\AtHocENS\ServerObjects\DotNet\gacutil.exe"
                Write-Verbose "%gacDirectory% $gacDirectory"
                if (Test-Path $gacDirectory) {
                    $isGac = $true
                    Write-Verbose "%isGac% $isGac"
                    if (Test-Path $gacUtil) {
                        Write-Log "Removing Windows Installer references..."
                        if (!(Remove-WinInstallerRef $gacDirectory)) {Exit-OnError "Removing WinInstaller references failed"}
                        Write-Log "Unregistering from GAC.."
                        if (!(Register-GAC $gacDirectory -unregister)) {Exit-OnError "Unregistering from GAC failed"}

                    } else {Write-Verbose "%gacUtil% $gacUtil"; Exit-OnError "Can't find $gacUtil"}
                }
            }

            #- deleting deprecated files
            if (!$Rollback) {
                if ($deleteList) {
                    Write-Log "Deleting deprecated files..."
                    if (!(Remove-Deprecated $deleteList)) {
                        if (!$Silent) {
                            if (Prompt-YesNo "Deleting deprecated files finished with errors" -question "Proceed?") {
                                Exit-OnError "Deleting deprecated files failed"
                            }

                        } else {Exit-OnError "Deleting deprecated files failed"}
                    }
                }
            }

            #- deleting new files, introduced by hotfix (Rollback mode only)
            if ($Rollback) {
                if ($bkpNewFiles) {
                    Write-log "Deleting new files from hotfix..."
                    foreach ($item in $bkpNewFiles) {
                        Write-Log "deleting: $item" -detailed
                        Remove-Item $item -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            #- merging hotfix directory structure with IWS installation directory
            if (!$Rollback) {
                Write-Log "Copying new files..."
                Write-Verbose "copying: $scriptDirectory\AtHocENS  to  $iwsInstallationDirectory"
                Try {Copy-Item -Path "$scriptDirectory\AtHocENS" -Destination "$iwsInstallationDirectory\..\" -Recurse -Filter {$_.Psiscontainer} -Force -ErrorAction Stop -ErrorVariable err10}
                Catch {Exit-OnError $err10}
            } else {Write-Log "Copying files from backup..."}

            #- creaing list of files to backup (Rollback mode only)
            if ($Rollback) {
                $athocEnsRelativeFilepaths = @()
                foreach ($item in $bkpFiles) {$athocEnsRelativeFilepaths += ([regex]::Match($item,'AtHocENS\\.*$')).Value}
                foreach ($item in $bkpDelFiles) {$athocEnsRelativeFilepaths += ([regex]::Match($item,'AtHocENS\\.*$')).Value}
            }

            #- copying files
            if ($athocEnsRelativeFilepaths.length -eq 0) {Write-Verbose "%athocEnsRelativeFilepaths% <empty>"}
            foreach ($relPath in $athocEnsRelativeFilepaths) {
                if (!$Rollback) {
                    $source =  "$scriptDirectory\$relPath"
                    $destination = $iwsInstallationDirectory + ([regex]::Match($relPath,'(?<=AtHocENS).*')).Value
                } else {
                    $source =  "$backupDirectory\$relPath"
                    $destination = $iwsInstallationDirectory + ([regex]::Match($relPath,'(?<=AtHocENS).*')).Value
                }
                Write-Log "copying: $source  to  $destination" -detailed | Out-Null
                Copy-Item $source -Destination $destination -Force -ErrorAction Stop -ErrorVariable err9
                if ($err9) {Exit-OnError $err9}
            }

            #- registering new COMs to Registry
            if ($isComs) {
                Write-Log "Registering COMs..."
                Write-Verbose "%comDirectory% $comDirectory"
                if (!(Register-COMs $comDirectory)) {Exit-OnError "Registering COMs failed"}
            }

            #- registering new assemblies to GAC
            if ($isGac) {
                if (Test-Path $gacUtil) {
                    Write-Log "Registering to GAC.."
                    if (!(Register-GAC $gacDirectory)) {Exit-OnError "Registering to GAC failed"}
                } else {Exit-OnError "Can't find $gacUtil"}
            }


            #- running GatewayInstaller
            Write-Verbose "%gatewayInstallerList% $gatewayInstallerList"
      			if ($gatewayInstallerList) {
      				Write-Log "Running GatewayInstaller..."
      				if (!(Run-GatewayInstaller $gatewayInstallerList)) {
      					if (Prompt-YesNo "Running GatewayInstaller finished with errors.You can cancel installation now, or you can manually enable failed gateways later using $iwsInstallationDirectory\ServerObjects\Tools\AtHoc.Applications.Tools.InstallPackage.exe" -question "Cancel installation?") {
      						Write-Log "Installation cancelled"
      						exit
      					}
      				}
      			}

            #- starting Application server, unless required to be stopped for Database upgrade
            if (!$StopAppForDatabaseUpgrade) {Start-Application}

        } elseif ($server -ne "all".ToLower()) {
            Write-Log "Can't find $scriptDirectory\AtHocENS. Skipping."
        }
    }
}


#=== RUNS CUSTOM SCRIPT

if (($server.ToLower() -eq "application".ToLower()) -or ($server.ToLower() -eq "all".ToLower())) {

	if (!$NoCustomScript) {

		if ($Rollback) {
		
			#- checks if custom script exists
			if ($customScriptRollback) {
				Write-Log "CUSTOM SCRIPT"
				$customScriptRlbFullPath = "$scriptDirectory\$customScriptRollback"
				if (!(Test-Path $customScriptRlbFullPath)) {Exit-OnError "CustomScriptRollback expected: `"$customScriptRollback`", but such file does not exist in $scriptDirectory. Hotfix package may be incomplete"}
			} else {
				$runCS = $false
			}
			
			#- checks if CustomScript Rollback properties file exists
			if ($runCS) {
				if (!(Test-Path $CustomScriptRlbProperties) -or ((Validate-CsRollbackfile $CustomScriptRlbProperties) -eq "invalid")) {
					Write-Log "No CustomScript execution record found. Skipping..." -warning
					Remove-Item $CustomScriptRlbProperties -Force -ErrorAction SilentlyContinue
					$runCS = $false
				}
			}
		
		} else {
		
			#- checks if custom script exists
			if ($customScript) {
				Write-Log "CUSTOM SCRIPT"
				$customScriptFullPath = "$scriptDirectory\$customScript"
				if (!(Test-Path $customScriptFullPath)) {Exit-OnError "CustomScript expected: `"$CustomScript`", but such file does not exist in $scriptDirectory. Hotfix package may be incomplete"}
			} else {
				$runCS = $false
			}
			
			#- validates CustomScriptRlbProperties file
			if ($runCs) {
				if (Test-Path "$CustomScriptRlbProperties") {
					$csRollbackValidation = Validate-CsRollbackfile $CustomScriptRlbProperties
					
					if ($csRollbackValidation -eq "successful") {
						Write-Log "CustomScript `"$CustomScript`" has been previously successfully executed. Skipping..." -warning
						$runCS = $false
					} elseif ($csRollbackValidation -eq "failed") {
						Write-Log "Previous attempt to execute this CustomScript failed and has not been rolled back." -warning
						if (Prompt-YesNo "You can cancel installation now and then run the script again in Rollback mode to clean up, or you can proceed, but execution of CustomScript will be skipped." -question "Cancel installation?") {
							Write-Log "Installation cancelled."
							exit
						} else {
							Write-Log "CustomScript execution will be skipped..." -warning
							$runCS = $false
						}
					}				
				}
			}
		}

		Write-Verbose "%runCS% $runCS"
		Write-Verbose "%customScript% $customScript"
		Write-Verbose "%customScriptRollback% $customScriptRollback"

		#--- CUSTOM SCRIPT EXECUTION
		
		if ($runCS) {
			
			$cscriptResult = $true
			
			if ($Rollback) {

				$customCommandLine = "$customScriptRlbFullPath $customArgsRollback"
				Write-Log "Running: $customCommandLine"
				Write-Log "cs rlbk start >>>"
                try {
                    & "$customScriptRlbFullPath" $customArgsRollback
                } catch {
                    $cscriptResult = $false
                    write-log $_
                    Exit-OnError "CustomScript rollback failed to execute."	
                }
                Remove-Item $CustomScriptRlbProperties -Force -ErrorAction SilentlyContinue
				Write-Log ">>> cs rlbk end"

			} else {
			
				"CSCRIPT::start" | Out-File $CustomScriptRlbProperties -Append
				$customCommandLine = "$customScriptFullPath $customArgs"				
				Write-Log "Running: $customCommandLine"
				Write-Log "  cs start >>>"
                try {
                    & "$customScriptFullPath" $customArgs
                } catch {
                    $cscriptResult = $false
                    write-log $_
                }
				"CSCRIPT::$cscriptResult" | Out-File $CustomScriptRlbProperties -Append
				if (!$cscriptResult) {Exit-OnError "CustomScript failed to execute. If you want to run it manually, please first run `'Install.ps1`' in rollback mode."}
				Write-Log "  >>> cs end"
			}
		}
	}
}


#=== APPLIES DATABASE SERVER PATCH

if (($server.ToLower() -eq "database".ToLower()) -or ($server.ToLower() -eq "all".ToLower()))  # applying Database server patch
{
    Write-Log "DATABASE SERVER UPDATE"

	if (Test-Path "$iwsInstallationRegistry") {
        $DatabaseConnectionString = (Get-Item $iwsInstallationRegistry).GetValue("OleDbConnectionString")
        Write-Verbose "%DatabaseConnectionString% <found in Registry, secured>"
    } else {
        $DatabaseConnectionString = ""
        Write-Verbose "%DatabaseConnectionString% <! not found in Registry>"
    }

    if ($Rollback) {$sqlDirectory = "$scriptDirectory\SQL\Rollback"}
    else {$sqlDirectory = "$scriptDirectory\SQL\Install"}
    Write-Verbose "%sqlDirectory% $sqlDirectory"

    if (Test-Path $sqlDirectory) {

        #- validating Database connection parameters
        if (!$DbUser) {

            Write-Log "Database username not provided. Attempting to read from the Registry..." -detailed | Out-Null
            $DbUser = ([regex]::Match(($DatabaseConnectionString),'(?<=User\sId\=).*(?=\;Password)').Value)
            if (!$DbUser) {Exit-OnError "OleDbConnection string not found in Registry. Please provide Database username."}
        }

        if (!$DbPassword) {

            Write-Log "Database password not provided. Attempting to read from the Registry..." -detailed | Out-Null
            $DbPassword = ([regex]::Match(($DatabaseConnectionString),'(?<=Password\=)[^;]*').Value)
            if (!$DbPassword) {Exit-OnError "OleDbConnection string not found in Registry. Please provide Database password."}
        }

        if (!$DbInstance) {

            Write-Log "Database server(\instance) not provided. Attempting to read from the Registry..." -detailed | Out-Null
            $DbInstance = ([regex]::Match(($DatabaseConnectionString),'(?<=Server\=).*(?=\;Initial)').Value)
            if (!$DbInstance) {
                Write-Log "No Database server(\instance) data found in Registry. Setting to localhost\default (`".`")" -detailed
                $DbInstance = "."
            }

            Write-Log "Database user: $DbUser" | Out-Null
            Write-Log "Database instance: $DbInstance" | Out-Null

            #- running test query to validate Database connection and to determine installed IWS version
            Write-Log "Trying to connect to database server..." | Out-Null
            $testSqlQuery = "select CURRENT_MNGT_VERSION from ngaddata.dbo.SYSTEM_PARAMS_TAB"
            $testSqlArg = "-U $DbUser -P $DbPassword -S $DbInstance -I -b -x -l 30 -V 1 -Q `"$testSqlQuery`""
            Write-Verbose ("test SQL: sqlcmd -U $DbUser -P ***** -S $DbInstance -I -b -x -l 30 -V 1 -Q `"$testSqlQuery`"")
            $testSqlRun = Run-Process -processName sqlcmd -arguments $testSqlArg
            if ($testSqlRun.errcode -gt 0) {Write-Log $testSqlRun.stdout | Out-Null; Exit-OnError $testSqlRun.stderr}
            else {Write-Log "connection successful" -detailed | Out-Null}

            $IWSversionDB = ([regex]::Match(($testSqlRun.stdout),'(?<=\W)\d\.\d\.\d\..*(?=\W)').Value).trim()
            if ($IWSversionDB -ne $hotfixTargetVersion) {Exit-OnError "Version mismatch. Hotfix: $hotfixTargetVersion;  Installed DB server version: $IWSversionDB"}
        }

        #- running check against database to see if patch applied
        Write-Log "Checking if patch has been already applied..." | Out-Null
        $hotFixInstalled = $false
        $testSqlQuery = "select HOT_FIX_ID from ngaddata.dbo.SYS_PRODUCT_HOTFIX_TAB where HOT_FIX_ID = `'$hotfixID`'"
        $testSqlArg = "-U $DbUser -P $DbPassword -S $DbInstance -I -b -x -l 30 -V 1 -Q `"$testSqlQuery`""
        Write-Verbose ("test SQL: sqlcmd -U $DbUser -P ***** -S $DbInstance -I -b -x -l 30 -V 1 -Q `"$testSqlQuery`"")
        $testSqlRun = Run-Process -processName sqlcmd -arguments $testSqlArg
        if ($testSqlRun.errcode -gt 0) {Write-Log $testSqlRun.stdout | Out-Null; Exit-OnError $testSqlRun.stderr}
        else {
            if ($Rollback) {
                if ($testSqlRun.stdout -like '*(0 rows affected)*') {
                    Write-Log "Database: This hotifx has not been applied to Database yet. Skipping..." -warning
                    $runDB = $false
                }
            } else {
                if ($testSqlRun.stdout -notlike '*(0 rows affected)*') {
                    Write-Log "Database: This hotfix has been applied to Database already. Skipping..." -warning
                    $runDB = $false
                }
            }
        }

        if ($runDB) {
            #- collecting list of sql files to run
            $sqlFilesList = @()
            $nestedSqlDirectories = Get-ChildItem $sqlDirectory | ?{$_.PSIsContainer}
            if ($nestedSqlDirectories) {
                foreach ($directory in ($nestedSqlDirectories | sort -Property Name)) {
                    $sqlFilesList += (Get-ChildItem $directory.FullName -Filter '*.sql')
                }
            }

            #- collecting list of sql files directly in SQL directory
            $sqlFilesList += (Get-ChildItem $sqlDirectory -Filter '*.sql' | sort -Property FullName)

            #- running sql files
            Write-Log "Executing SQL queries..."
            Execute-SqlFiles $sqlFilesList
        }

    } elseif ($server -ne "all".ToLower()) {
        Write-Log "Can't find $scriptDirectory\SQL. Nothing to update on Database server"
    }
}


#=== STARTS APPLICATOIN SERVER

if ($StopAppForDatabaseUpgrade -and (($server.ToLower() -eq "application".ToLower()) -or ($server.ToLower() -eq "all".ToLower()))) {Start-Application}


#=== END ===

#- removing Rollback properties file
if ($Rollback) {
    if (($server.ToLower() -eq"application".ToLower()) -or ($server.ToLower() -eq"all".ToLower())) {
        Remove-Item $RollbackProperties -Force -ErrorAction SilentlyContinue
    }
}

Close-Log
exit

# SIG # Begin signature block
# MIIcZQYJKoZIhvcNAQcCoIIcVjCCHFICAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUAfKxn64S+RGIU8z7KELS8RP7
# g6WgghecMIIFJTCCBA2gAwIBAgIQDmSclMkHqgxlAKzxBXJn4zANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE2MDYwMzAwMDAwMFoXDTE5MDgw
# NzEyMDAwMFowYjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExEjAQ
# BgNVBAcTCVNhbiBNYXRlbzEUMBIGA1UEChMLQXRIb2MsIEluYy4xFDASBgNVBAMT
# C0F0SG9jLCBJbmMuMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkhIZ
# lNyvjA4mK2NolOZu1iEQOO4drVhUIWF41PMKAkgGFjrzDfh/BXz3FVx9VdUjL4pC
# ofSYoA1AhqS0hnE9WJbm4MwQ8N5j4utTrVvQ0miaBv/oXDmu9ldKZt1sWjMMce+s
# Tv+ivZtcWO7AsdyDxN+PKWHmMsyy4GW1JamvnxswkrlIa73xkjPa3lf0bczPPNSG
# r0nB/Faz43dqOqjsl8AkFPBwLwDOPj5j8KlyAClykmhCGqwkiUHv74qFuNFJ4tqs
# CGA7Pibljzbrv7O0yRokRtdw4pvkYxJxSv2M+g3j8XYPYUWJjgCqiBm0spcfrQe4
# OjN2oKaK6jIDD0SvywIDAQABo4IBxTCCAcEwHwYDVR0jBBgwFoAUWsS5eyoKo6Xq
# cQPAYPkt9mV1DlgwHQYDVR0OBBYEFNwsqBUYkuW6dZnsv7tjdcyy2pqrMA4GA1Ud
# DwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Ax
# hi9odHRwOi8vY3JsMy5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNy
# bDA1oDOgMYYvaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1j
# cy1nMS5jcmwwTAYDVR0gBEUwQzA3BglghkgBhv1sAwEwKjAoBggrBgEFBQcCARYc
# aHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAIBgZngQwBBAEwgYQGCCsGAQUF
# BwEBBHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4G
# CCsGAQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRT
# SEEyQXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkq
# hkiG9w0BAQsFAAOCAQEAkzeuNJqoW0w1lz8/IxzD+t0fhrafn49yXB5ZTaTqK20q
# wC2jC+ul982dCMFDBagFYWCDnlNQJ0wg/L7Zdb4Y8lQPoL/qs0RAbiq6vLkYmryF
# pgdWoRpA3A02xp/Qj/etaA5ZP763j3rBb5KH/djXmb4ZxsqYM+QGVzqtpXRHGeDR
# Sg4JiiyGMOfnQqIzjKR7ntv/sZ+vQlFW7cDMabJbgSozI3ljuL+5bFo5ZMzLQmLR
# EpediOVDtgi0Dl0+k0xCu5vIn6C5dbiJYnH1zD6CJuLlYay2vJX6M2zaxuHchUsL
# Tn8ezOGBRs6wCtYeGJL0VmFL0qDgIfLR6enLwGkYlzCCBTAwggQYoAMCAQICEAQJ
# GBtf1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEk
# MCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEy
# MDAwMFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
# Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMo
# RGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE6
# 20T1f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG
# +yknx9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwg
# la4cSocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q1
# 6XTmK/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTF
# jg/BougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOC
# Ac0wggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0
# cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0
# cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNV
# HR8EejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRB
# c3N1cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5j
# b20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZI
# AYb9bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20v
# Q1BTMAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAf
# BgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOC
# AQEAPuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3
# sOH20ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsH
# DpEV+7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlx
# sQyPu6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy
# 62ZD2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQY
# hS6SkepobEQysmah5xikmmRR7zCCBmowggVSoAMCAQICEAMBmgI6/1ixa9bV6uYX
# 8GYwDQYJKoZIhvcNAQEFBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGln
# aUNlcnQgQXNzdXJlZCBJRCBDQS0xMB4XDTE0MTAyMjAwMDAwMFoXDTI0MTAyMjAw
# MDAwMFowRzELMAkGA1UEBhMCVVMxETAPBgNVBAoTCERpZ2lDZXJ0MSUwIwYDVQQD
# ExxEaWdpQ2VydCBUaW1lc3RhbXAgUmVzcG9uZGVyMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEAo2Rd/Hyz4II14OD2xirmSXU7zG7gU6mfH2RZ5nxrf2uM
# nVX4kuOe1VpjWwJJUNmDzm9m7t3LhelfpfnUh3SIRDsZyeX1kZ/GFDmsJOqoSyyR
# icxeKPRktlC39RKzc5YKZ6O+YZ+u8/0SeHUOplsU/UUjjoZEVX0YhgWMVYd5SEb3
# yg6Np95OX+Koti1ZAmGIYXIYaLm4fO7m5zQvMXeBMB+7NgGN7yfj95rwTDFkjePr
# +hmHqH7P7IwMNlt6wXq4eMfJBi5GEMiN6ARg27xzdPpO2P6qQPGyznBGg+naQKFZ
# OtkVCVeZVjCT88lhzNAIzGvsYkKRrALA76TwiRGPdwIDAQABo4IDNTCCAzEwDgYD
# VR0PAQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwggG/BgNVHSAEggG2MIIBsjCCAaEGCWCGSAGG/WwHATCCAZIwKAYIKwYBBQUH
# AgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwggFkBggrBgEFBQcCAjCC
# AVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABp
# AGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBw
# AHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAAQwBQ
# AC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQBy
# AHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0
# ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwBy
# AHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBl
# AG4AYwBlAC4wCwYJYIZIAYb9bAMVMB8GA1UdIwQYMBaAFBUAEisTmLKZB+0e36K+
# Vw0rZwLNMB0GA1UdDgQWBBRhWk0ktkkynUoqeRqDS/QeicHKfTB9BgNVHR8EdjB0
# MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVk
# SURDQS0xLmNybDA4oDagNIYyaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0QXNzdXJlZElEQ0EtMS5jcmwwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzAB
# hhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9j
# YWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3J0MA0G
# CSqGSIb3DQEBBQUAA4IBAQCdJX4bM02yJoFcm4bOIyAPgIfliP//sdRqLDHtOhcZ
# cRfNqRu8WhY5AJ3jbITkWkD73gYBjDf6m7GdJH7+IKRXrVu3mrBgJuppVyFdNC8f
# cbCDlBkFazWQEKB7l8f2P+fiEUGmvWLZ8Cc9OB0obzpSCfDscGLTYkuw4HOmksDT
# jjHYL+NtFxMG7uQDthSr849Dp3GdId0UyhVdkkHa+Q+B0Zl0DSbEDn8btfWg8cZ3
# BigV6diT5VUW8LsKqxzbXEgnZsijiwoc5ZXarsQuWaBh3drzbaJh6YoLbewSGL33
# VVRAA5Ira8JRwgpIr7DUbuD0FAo6G+OPPcqvao173NhEMIIGzTCCBbWgAwIBAgIQ
# Bv35A5YDreoACus/J7u6GzANBgkqhkiG9w0BAQUFADBlMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMDYxMTEw
# MDAwMDAwWhcNMjExMTEwMDAwMDAwWjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQD
# ExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTEwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDogi2Z+crCQpWlgHNAcNKeVlRcqcTSQQaPyTP8TUWRXIGf7Syc
# +BZZ3561JBXCmLm0d0ncicQK2q/LXmvtrbBxMevPOkAMRk2T7It6NggDqww0/hhJ
# gv7HxzFIgHweog+SDlDJxofrNj/YMMP/pvf7os1vcyP+rFYFkPAyIRaJxnCI+QWX
# faPHQ90C6Ds97bFBo+0/vtuVSMTuHrPyvAwrmdDGXRJCgeGDboJzPyZLFJCuWWYK
# xI2+0s4Grq2Eb0iEm09AufFM8q+Y+/bOQF1c9qjxL6/siSLyaxhlscFzrdfx2M8e
# CnRcQrhofrfVdwonVnwPYqQ/MhRglf0HBKIJAgMBAAGjggN6MIIDdjAOBgNVHQ8B
# Af8EBAMCAYYwOwYDVR0lBDQwMgYIKwYBBQUHAwEGCCsGAQUFBwMCBggrBgEFBQcD
# AwYIKwYBBQUHAwQGCCsGAQUFBwMIMIIB0gYDVR0gBIIByTCCAcUwggG0BgpghkgB
# hv1sAAEEMIIBpDA6BggrBgEFBQcCARYuaHR0cDovL3d3dy5kaWdpY2VydC5jb20v
# c3NsLWNwcy1yZXBvc2l0b3J5Lmh0bTCCAWQGCCsGAQUFBwICMIIBVh6CAVIAQQBu
# AHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0
# AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABhAG4AYwBl
# ACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBDAFAAUwAg
# AGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5ACAAQQBn
# AHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABsAGkAYQBi
# AGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABvAHIAYQB0
# AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBjAGUALjAL
# BglghkgBhv1sAxUwEgYDVR0TAQH/BAgwBgEB/wIBADB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDAd
# BgNVHQ4EFgQUFQASKxOYspkH7R7for5XDStnAs0wHwYDVR0jBBgwFoAUReuir/SS
# y4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQEFBQADggEBAEZQPsm3KCSnOB22Wymv
# Us9S6TFHq1Zce9UNC0Gz7+x1H3Q48rJcYaKclcNQ5IK5I9G6OoZyrTh4rHVdFxc0
# ckeFlFbR67s2hHfMJKXzBBlVqefj56tizfuLLZDCwNK1lL1eT7EF0g49GqkUW6aG
# MWKoqDPkmzmnxPXOHXh2lCVz5Cqrz5x2S+1fwksW5EtwTACJHvzFebxMElf+X+Ee
# vAJdqP77BzhPDcZdkbkPZ0XN1oPt55INjbFpjE/7WeAjD9KqrgB87pxCDs+R1ye3
# Fu4Pw718CqDuLAhVhSK46xgaTfwqIa1JMYNHlXdx3LEbS0scEJx3FMGdTy9alQgp
# ECYxggQzMIIELwIBATCBhjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNl
# cnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdp
# Q2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBAhAOZJyUyQeqDGUA
# rPEFcmfjMAkGBSsOAwIaBQCgcDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0B
# CQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAj
# BgkqhkiG9w0BCQQxFgQUjGSC0ZkqDgpwv+ooElQ703SSHyIwDQYJKoZIhvcNAQEB
# BQAEggEAajINEblFE8G+VbOEMclv12pnhSRTVX+PlZxhU9tHQ6OrirehQqXESOt9
# GMoRMeSHmZfRjaGGlqlhDhN9585CZeKv1B07Q72rA+W8ceAgGP3jFrTh2umnHjEY
# VisVzd6S5D7cs/yz1Bpf0bdLgEvd8yez3P4Gk7BWOOanhXFTUOFaU6GDxfRbNp05
# 0Gb2QmfSqtP+wfgeBq0WmLHDlCLgo/AJanaL8aw5OV2NluA4im6azpEE2hQVClKJ
# He4HGjv9LZ/eDF7zLHB8ak4dNwZ/zJIR08Job5NSJqQaGc5TvkVOBsPoHqE9LI/s
# 1OQD0xinpSkaEtg6dzHhZ9fHRTMqnKGCAg8wggILBgkqhkiG9w0BCQYxggH8MIIB
# +AIBATB2MGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3Vy
# ZWQgSUQgQ0EtMQIQAwGaAjr/WLFr1tXq5hfwZjAJBgUrDgMCGgUAoF0wGAYJKoZI
# hvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTgwMzAyMjEwMTAy
# WjAjBgkqhkiG9w0BCQQxFgQUR1nNDR5+VzBuEBzxC4qI3SED6oAwDQYJKoZIhvcN
# AQEBBQAEggEADkNtym+QYYD86m3kGKIMpKvG9JMfFfG1dcu/xMTk4d+XiXCVECEd
# lJTP9h8abChXel1kvJwRPHq1nhmwfDPc+WYWEiajLI02bk3HnqwVKnv4NkJQglPF
# iTsxnjefRJa7spbZoacdw7sYgVzX6D5kbff82kuw+vpCvnH1kTh41ceRD2T7Y1i3
# OqgHayeZgPVBRt7nTzL4GQZTYlKySlXGNVA26JIDQe5F6iLWFbKVXBb9IvFCcATc
# jBZfvzW7AOMVT9WF3JSXxhUcWuB4GgFSTptJrWjZBcgb9ddrHK2RztTLw1bK9IUQ
# +skMT6Jm4z98MJSzv1ZMba5qWFftX9Q8QA==
# SIG # End signature block
