# 2016 Pavel Stsefanovich
# Jenkins calls this script in "Hotfix Package" job

Param (
    [string]$envJiraIssue,
    [string]$envJiraTitle,
    [string]$envSvnBranch,
    [string]$envRecipients,
    [string]$envCOMs,
    [string]$envGAC,
    [string]$envGateways,
    [string]$envFilesReplace,
    [string]$envFilesDelete,
    [string]$envSQLfiles,
    [string]$envSQLfilesRollB,
    [string]$envReadmePreface,
    [string]$envReadmeAppendix,
    [string]$envCustomScript,
    [string]$envCustomArgs,
    [string]$envCustomScriptRollback,
    [string]$envCustomArgsRollback,
    [string]$envWorkspace,
    [string]$envBuildName,
    [string]$envBuildNumber,
    [string]$envBuildUrl
)


function Exit-OnError ([string]$message,[switch]$noMail) {
    Write-Output "`n!!ERROR: $message"
    Write-Output ""
    if (!$noMail) {
      Send-Email $script:itemsRecipients -fail -errormessage $message
    }
    exit 1
}

function Build-ParametersList {

    $parameters = @(" ",
                    "----- INPUT PARAMETERS ----------------------------------------",
                    "JiraIssue:`t`t$itemJiraIssue`n",
                    "JiraTitle:`t`t$itemJiraTitle`n",
                    "SvnBranch:`t`t$envSvnBranch`n")

    $parameters += ,("Recipients:`t`t" + $itemsRecipients[0])
    [int]$i = 1
    while ($i -lt $itemsRecipients.length) {$parameters += ,("`t`t`t" + $itemsRecipients[$i] ); $i++ }
    $parameters += ,("")
    $parameters += ,("")

    if ($itemComs) {
        $parameters += ,("COMs:`t`t`t$itemComs")
        $parameters += ,("")
    }

    if ($itemsToGac) {
        $parameters += ,("GAC:`t`t`t" + $itemsToGac[0])
        [int]$i = 1
        while ($i -lt $itemsToGac.length) {$parameters += ,("`t`t`t" + $itemsToGac[$i] ); $i++ }
        $parameters += ,("")
    }

    if ($itemsGateways) {
        $parameters += ,("Gateways:`t`t" + $itemsGateways[0])
        [int]$i = 1
        while ($i -lt $itemsGateways.length) {$parameters += ,("`t`t`t" + $itemsGateways[$i] ); $i++ }
        $parameters += ,("")
    }

    if ($itemsToReplace) {
        $parameters += ,("FilesReplace:`t`t" + $itemsToReplace[0])
        [int]$i = 1
        while ($i -lt $itemsToReplace.length) {$parameters += ,("`t`t`t" + $itemsToReplace[$i] ); $i++ }
        $parameters += ,("")
    }

    if ($itemsToDelete) {
        $parameters += ,("FilesDelete:`t`t" + $itemsToDelete[0])
        [int]$i = 1
        while ($i -lt $itemsToDelete.length) {$parameters += ,("`t`t`t" + $itemsToDelete[$i] ); $i++ }
        $parameters += ,("")
    }

    if ($itemsSql) {
        $parameters += ,("SQLfiles:`t`t" + $itemsSql[0])
        [int]$i = 1
        while ($i -lt $itemsSql.length) {$parameters += ,("`t`t`t" + $itemsSql[$i] ); $i++ }
        $parameters += ,("")
    }

    if ($itemsSqlRollB) {
        $parameters += ,("SQLfilesRollB:`t`t" + $itemsSqlRollB[0])
        [int]$i = 1
        while ($i -lt $itemsSqlRollB.length) {$parameters += ,("`t`t`t" + $itemsSqlRollB[$i] ); $i++ }
        $parameters += ,("")
    }

    if ($itemReadmePreface) {
        $parameters += ,("ReadmePreface:`t`t$itemReadmePreface")
        $parameters += ,("")
    }

    if ($itemReadmeAppendix) {
        $parameters += ,("ReadmeAppendix:`t`t$itemReadmeAppendix")
        $parameters += ,("")
    }

    if ($itemCustomScript) {
        $parameters += ,("CustomScript:`t`t" + ($itemCustomScript | Split-Path -Leaf))
        $parameters += ,("")
    }

    if ($itemCustomArgs) {
		$parameters += ,("CustomArgs:`t`t$itemCustomArgs")
		$parameters += ,("")
	}
	
    if ($itemCustomScriptRollback) {
        $parameters += ,("CustomScriptRollback:`t" + ($itemCustomScriptRollback | Split-Path -Leaf))
        $parameters += ,("")
    }

    if ($itemCustomArgsRollback) {
		$parameters += ,("CustomArgsRollback:`t$itemCustomArgsRollback")
		    $parameters += ,("")
		}
	
    $parameters += ,("===== INPUT PARAMETERS ========================================")

    return $parameters
}

function Print-Parameters ([string]$filename) {

    if ($filename) {
        "Build URL:`t$envBuildUrl" | Out-File $filename
        "Built on:`t" + (Get-Date -Format F) | Out-File $filename -Append
        $parametersList | Out-File $filename -Append
        " " | Out-File $filename -Append
    }
    else {
        foreach ($line in $parametersList) {Write-Output $line}
        Write-Output " "
    }
}

function Write-Readme ([string]$line) {

    if ($line) {$line >> $readmeFile}

    else {
        ("$itemReleaseVersion HotFix created on " + (Get-Date -Format g) + "`n") > $readmeFile
        " " >> $readmeFile
        "$itemJiraIssue : $itemJiraTitle" >> $readmeFile
        " " >> $readmeFile
        if ($envSvnBranch -like '*87CP1_CHF') {
            "COMPATIBILITY : This hotfix is compatible with IWS $itemReleaseVersion (Cumulative hotfix #3)" >> $readmeFile
        } else {
            "COMPATIBILITY : This hotfix is compatible with IWS $itemReleaseVersion" >> $readmeFile
        }
        " " >> $readmeFile
    }
}

function Write-Propertiesfile ([string]$line) {

    if ($line) {$line >> $installPropertiesFile}

    else {" " > $installPropertiesFile}
}

function Send-Email ([switch]$fail,[string]$errormessage) {

    Write-Output "Sending Email notification to: $script:itemsRecipients"
    $SMTPServer = "atcasht.athoc.com"
    #$attachment = New-Object Net.Mail.Attachment($packageinfoFile)
    $message = New-Object Net.Mail.MailMessage
    $smtp = New-Object Net.Mail.SmtpClient($SMTPServer, 25)
    $message.From = "br@athoc.com"
    foreach ($item in $script:itemsRecipients) {$message.To.Add($item)}
    if ($fail) {
        $message.Subject = "Hotfix $script:itemJiraIssue($script:itemReleaseVersion) packaging FAILED"
        $message.IsBodyHtml = $true
        $message.Body = "ERROR: $errormessage<br /><br />$script:envBuildUrl"
    } else {
        $message.Subject = "Hotfix $script:itemJiraIssue($script:itemReleaseVersion) successfully packaged"
        $message.Body = Get-Content $script:packageinfoFile | Out-String
    }
    #$message.Attachments.Add($attachment)
    $smtp.Send($message)

}


#=== INPUT PARAMETERS VALIDATION ===

$somethingToPackage = $false

#- JiraIssue
if (!$envJiraIssue -or ($envJiraIssue -eq 'HF-')) {Exit-OnError "Parameter not provided: < JiraIssue >"}
else {$itemJiraIssue = $envJiraIssue}

#- JiraTitle
if (!$envJiraTitle) {Exit-OnError "Parameter not provided: < JiraTitle >"}
else {$itemJiraTitle = $envJiraTitle}

#- SvnBranch (does it need validation in case Jenkins screws?) -- answer is Yes!!
if ($envSvnBranch -like '*87CP1_CHF') {$itemReleaseVersion = $envSvnBranch.TrimEnd('_CHF')}
else {$itemReleaseVersion = $envSvnBranch}

#- Recipients
if (!$envRecipients) {Exit-OnError "Parameter not provided: < Recipients >. You must specify at least one person to receive Hotfix package"}
foreach ($item in $envRecipients.TrimEnd(',').Split(',')) {
    if (!($item -match('\b[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}\b'))) {$badAddressList += "$item`n"}
    else {$itemsRecipients += ,($item.Trim())}
}
if ($badAddressList.Length -gt 0) {$errorMessage = "Incorrect email address(es):`n" + $badAddressList;  Exit-OnError $errorMessage -noMail}

#- COMs
    if ($envCOMs -eq 'true') {$itemComs = $true; $somethingToPackage = $true}
    else {$itemComs = $false}

#- GAC
if ($envGAC) {
    $somethingToPackage = $true
    foreach ($item in $envGAC.TrimEnd(',').Split(',')) {
        if (($item.trim().contains("`n")) -or ($item.trim().contains("`r"))) {$errorMessage = "Comma missing between GAC entries:`n" + $item; Exit-OnError $errorMessage}
            elseif (($item.trim() -notlike '*.dll') -or $item.contains('/') -or $item.contains('\')) {$badGacNames += "$item`n"}
            else {$itemsToGac += ,($item.Trim())}
    }
    if ($badGacNames.length -gt 0) {$errorMessage = "Incorrect GAC assembly name(s):`n" + $badGacNames; Exit-OnError $errorMessage}
}

#- Gateways
if ($envGateways) {
    $somethingToPackage = $true
    if (Test-Path "$scriptDirectory\Gateways.List.txt") {$availableGateways = Get-Content "$scriptDirectory\Gateways.List.txt"}
    else {
        $availableGateways =  @('ADT Giant Voice',
	                            'AlertUs Beacon',
	                            'AM Radio',
	                            'AM Radio Bluegrass',
	                            'American Signal Giant Voice',
	                            'American Signal Giant Voice - V2',
	                            'Mobile App',
	                            'AtHoc Cloud Delivery Service (East Coast)',
	                            'AtHoc Cloud Delivery Service (West Coast)',
	                            'AtHoc Connect',
	                            'AtHoc Media Player(AMP)',
	                            'ATI Giant Voice',
	                            'Benbria Classroom Emergency Notification',
	                            'Cable TV + Radio',
	                            'Cable TV Scroller',
	                            'CAWS',
	                            'CentrAlert',
	                            'Cisco Digital Media Player',
	                            'Cisco UCM - Auto Answer Speaker Phone',
	                            'Cisco UCM (Blast)',
	                            'Cisco UCM (TAS and Blast)',
	                            'Cisco UCM (TAS)',
	                            'Cisco Unified Communication Manager',
	                            'Community Warning System Feeds',
	                            'Cooper Notification WAVES',
	                            'DTMF Activated Device',
	                            'eMerge eNotify',
	                            'Emergency Digital Information Service (EDIS)',
	                            'Federal Signal Giant Voice',
	                            'Indoor Fire Panel',
	                            'Industrial Strobe Beacon',
	                            'IPAWS',
	                            'Land Mobile Radio',
	                            'Land Mobile Radio - Eastman',
	                            'Land Mobile Radio - v2',
	                            'LED Sign',
	                            'Microsoft Lync',
	                            'Mobile App',
	                            'Monaco Warning System',
	                            'Motorola ACE3600',
	                            'On-Premise Email',
	                            'Public Address System',
	                            'RMG Digital Signage',
	                            'RSS Feed',
	                            'Siemens DAKS',
	                            'Simplex-Grinnell 4100U',
	                            'Talk-A-Phone Giant Voice',
	                            'TechRadium',
	                            'Text Messaging',
	                            'Twitter',
	                            'Xml Feed',
	                            'Zetron Pager',
	                            'Zetron Pager Group')
    }
    foreach ($item in $envGateways.TrimEnd(',').Split(',')) {
        $found = $false
        if (($item.trim().contains("`n")) -or ($item.trim().contains("`r"))) {$errorMessage = "Comma missing between Gateways entries:`n" + $item; Exit-OnError $errorMessage}
        foreach ($option in $availableGateways) {
            if ($item.Trim() -eq $option) {$found = $true; $itemsGateways += ,($item.Trim()); break}
        }
        if (!$found) {$badGatewayNames += ,($item.trim() + "`n")}
    }
    if ($badGatewayNames.Length -gt 0) {$errorMessage = "Incorrect Gateway name(s):`n" + $badGatewayNames; Exit-OnError $errorMessage}
}

#- FilesReplace
if ($envFilesReplace) {
    $somethingToPackage = $true
    foreach ($item in $envFilesReplace.TrimEnd(',').Split(',')) {
        if (($item.trim().contains("`n")) -or ($item.trim().contains("`r"))) {$errorMessage = "Comma missing between FilesReplace entries:`n" + $item; Exit-OnError $errorMessage}
            elseif ($item.Trim() -notlike 'AtHocENS\*') {$badReplacePaths += "$item`n"}
        else {$itemsToReplace += ,($item.Trim())}
    }
    if ($badReplacePaths.length -gt 0) {$errorMessage = "Incorrect FilesReplace path(s):`n" + $badReplacePaths; Exit-OnError $errorMessage}
}

#- FilesDelete
if ($envFilesDelete) {
    $somethingToPackage = $true
    foreach ($item in $envFilesDelete.TrimEnd(',').Split(',')) {
        if (($item.trim().contains("`n")) -or ($item.trim().contains("`r"))) {$errorMessage = "Comma missing between FilesDelete entries:`n" + $item; Exit-OnError $errorMessage}
            elseif ($item.Trim() -notlike 'AtHocENS\*') {$badDeletePaths += "$item`n"}
        else {$itemsToDelete += ,($item.Trim())}
    }
    if ($badDeletePaths.length -gt 0) {$errorMessage = "Incorrect FilesDelete path(s):`n" + $badDeletePaths; Exit-OnError $errorMessage}
}

#- SQLfiles
if ($envSQLfiles) {
    if (!$envSQLfilesRollB) {Exit-OnError "Parameter not provided: < SQLfilesRollB >, though <SQLfiles> provided. Are you missing SQL rollback files?"}
    $somethingToPackage = $true
    foreach ($item in $envSQLfiles.TrimEnd(',').Split(',')) {
        if (($item.trim().contains("`n")) -or ($item.trim().contains("`r"))) {$errorMessage = "Comma missing between SQLfiles entries:`n" + $item; Exit-OnError $errorMessage}
            elseif (($item.Trim() -notlike 'Database\*') -and ($item.Trim() -notlike 'Database/*')) {$badSqlPaths += "$item`n"}
        else {$itemsSql += ,($item.Trim())}
    }
    if ($badSqlPaths.length -gt 0) {$errorMessage = "Incorrect SQLfiles path(s):`n" + $badSqlPaths; Exit-OnError $errorMessage}
}

#- SQLfilesRollB
if ($envSQLfilesRollB) {
    if (!$envSQLfiles) {Exit-OnError "Parameter not provided: < SQLfiles >, though <SQLfilesRollB> provided. Are you missing SQL files?"}
    foreach ($item in $envSQLfilesRollB.TrimEnd(',').Split(',')) {
        if (($item.trim().contains("`n")) -or ($item.trim().contains("`r"))) {$errorMessage = "Comma missing between SQLfilesRollB entries:`n" + $item; Exit-OnError $errorMessage}
            elseif (($item.Trim() -notlike 'Database\*') -and ($item.Trim() -notlike 'Database/*')) {$badSqlRbPaths += "$item`n"}
        else {$itemsSqlRollB += ,($item.Trim())}
    }
    if ($badSqlRbPaths.length -gt 0) {$errorMessage = "Incorrect SQLfiles path(s):`n" + $badSqlRbPaths; Exit-OnError $errorMessage}
}

#- ReadmePreface
if ($envReadmePreface -and ($envReadmePreface.Length -gt 0)) {
    $readmeTempFileName = "$scriptDirectory\readmeTemp.txt" #(ps) this is intermediate file used as workaround for Jenkins Text parameter bug
    $envReadmePreface > $readmeTempFileName
    $itemReadmePreface = Get-Content $readmeTempFileName
}

#- ReadmeAppendix
if ($envReadmeAppendix -and ($envReadmeAppendix.Length -gt 0)) {
    $readmeTempFileName = "$scriptDirectory\readmeTemp.txt" #(ps) this is intermediate file used as workaround for Jenkins Text parameter bug
    $envReadmeAppendix > $readmeTempFileName
    $itemReadmeAppendix = Get-Content $readmeTempFileName
}

#- CustomScript
if ($envCustomScript) {
    $exceptedFilenames = @("Install.properties","Install.ps1","Readme.txt")
    if (($envCustomScript -in $exceptedFilenames) -or ($envCustomScript -like "packageinfo-*")) {
      Write-Output "Following values are not allowed as CustomScript filename:"
      $exceptedFilenames | %{Write-Output " - $_"}
      Write-Output " - packageinfo-*"
      Exit-OnError "Invalid CustomScript filename: `"$envCustomScript`""
    }
    $somethingToPackage = $true
    $itemCustomScript = $envWorkspace + "\" + $envCustomScript
    if (Test-Path $itemCustomScript) {Remove-Item $itemCustomScript -Force}
    Rename-Item .\CustomScript -NewName $envCustomScript -Force
}

#- CustomArgs
if ($envCustomArgs) {
    if (!$envCustomScript) {Exit-OnError "Parameter not provided: <CustomScript>, though <CustomArgs> provided. Are you missing script file?"}
    else {$itemCustomArgs = $envCustomArgs}
}

#- CustomScriptRollback
if ($envCustomScriptRollback) {
    $exceptedFilenames = @("Install.properties","Install.ps1","Readme.txt")
    if (($envCustomScriptRollback -in $exceptedFilenames) -or ($envCustomScriptRollback -like "packageinfo-*")) {
      Write-Output "Following values are not allowed as CustomScript filename:"
      $exceptedFilenames | %{Write-Output " - $_"}
      Write-Output " - packageinfo-*"
      Exit-OnError "Invalid CustomScript filename: `"$envCustomScriptRollback`""
    }
    $somethingToPackage = $true
    $itemCustomScriptRollback = $envWorkspace + "\" + $envCustomScriptRollback
    if (Test-Path $itemCustomScriptRollback) {Remove-Item $itemCustomScriptRollback -Force}
    Rename-Item .\CustomScriptRollback -NewName $envCustomScriptRollback -Force
}

#- CustomArgsRollback
if ($envCustomArgsRollback) {
    if (!$envCustomScriptRollback) {Exit-OnError "Parameter not provided: <CustomScriptRollback>, though <CustomArgsRollbackArgs> provided. Are you missing script file?"}
    else {$itemCustomArgsRollback = $envCustomArgsRollback}
}

if (!$somethingToPackage) {Exit-OnError "Nothing selected to be packaged into hotfix"}


#=== SCRIPT VARIABLES AND RESOURCES ===

#- Script directory
$scriptDirectory = $PSScriptRoot

#- Output directory
$outputDirectory = "$envWorkspace\Output"
if (!(Test-Path $outputDirectory)) {New-Item $outputDirectory -ItemType Directory | Out-Null}
$packageinfoFile = "$outputDirectory\packageinfo-$itemJiraIssue($itemReleaseVersion).txt"
$hotfixRootDirectory = "$outputDirectory\$itemJiraIssue($itemReleaseVersion)"
if (!(Test-Path $hotfixRootDirectory)) {New-Item $hotfixRootDirectory -ItemType Directory | Out-Null}

#- IWS package
$iwsArtifactsDirectory = "$envWorkspace\IWS.package"
$iwsPackageMask = "platform_build_full.zip"
if (!(Test-Path "$iwsArtifactsDirectory\*$iwsPackageMask")) {Exit-OnError "Can't find $iwsPackageMask in $iwsArtifactsDirectory"}
$iwsPackageFullpath = (Get-ChildItem "$iwsArtifactsDirectory\*$iwsPackageMask").FullName
Try {Add-Type -AssemblyName "system.io.compression.filesystem"} Catch {Exit-OnError $_}

#- Build and display parameters list
Write-Output "Packaging: $itemJiraIssue($itemReleaseVersion)"
$parametersList = Build-ParametersList
Print-Parameters

#- Package info file
Print-Parameters -filename $packageinfoFile
Copy-Item $packageinfoFile -Destination $hotfixRootDirectory -ErrorAction Stop

#- Installation properties file
$installPropertiesFile = "$hotfixRootDirectory\Install.properties"
Write-Propertiesfile

#- Install script and Readme file
Copy-Item "$scriptDirectory\Install.ps1" -Destination $hotfixRootDirectory -ErrorAction Stop
$readmeFile = "$hotfixRootDirectory\Readme.txt"
Write-Readme

#- ReadmePreface
if ($itemReadmePreface) {
    Write-Readme "_____________________________________________"
    Write-Readme " "
    foreach ($line in $itemReadmePreface) {
        $line >> $readmeFile
    }
    Write-Readme " "
}

#- Readme
foreach ($item in (Get-Content "$scriptDirectory\Readme-template.txt" -ErrorAction Stop)) {
    if ($item.Length -gt 0) {Write-Readme "$item"}
    else {Write-Readme " "}
}


#=== BUILDING HOTFIX STRUCTURE ===

#- Unzip IWS package
Write-Output "`nExtracting files from $iwsPackageFullpath to $iwsArtifactsDirectory..."
Try {[io.compression.zipfile]::ExtractToDirectory($iwsPackageFullpath,$iwsArtifactsDirectory)} Catch {Exit-OnError $_}

#- Coms
if ($itemComs) {
    Write-Output "`nCOMs"
    $hfComsDir = "$hotfixRootDirectory\AtHocENS\ServerObjects\COMs"
    New-Item $hfComsDir -ItemType Directory -Force | Out-Null
    foreach ($item in (Get-ChildItem "$iwsArtifactsDirectory\AtHocENS\ServerObjects\COMs" -Filter '*.dll')) {
        Write-Output ("`tcopying: " + $item.Fullname + "  to  " + $hfComsDir)
        Copy-Item $item.Fullname -Destination $hfComsDir -Force
    }
}

#- GAC
if ($itemsToGac) {
    Write-Output "`nGAC"
    $hfGacDir = "$hotfixRootDirectory\AtHocENS\ServerObjects\DOTNET"
    New-Item $hfGacDir -ItemType Directory -Force | Out-Null
    foreach($item in $itemsToGac) {
        if (Test-Path "$iwsArtifactsDirectory\AtHocENS\ServerObjects\DOTNET\$item") {
            Write-Output "`tcopying: $iwsArtifactsDirectory\AtHocENS\ServerObjects\DOTNET\$item  to  $hfGacDir"
            Copy-Item "$iwsArtifactsDirectory\AtHocENS\ServerObjects\DOTNET\$item" -Destination $hfGacDir -ErrorAction Stop
        } else {$badGacNames += "AtHocENS\ServerObjects\DOTNET\$item`n"}
    }
    if ($badGacNames.Length -gt 0) {$errorMessage = "< GAC > : can't find following files in IWS package:`n" + $badGacNames; Exit-OnError $errorMessage}

    $gacutilFiles = @("gacutil.exe","gacutil.exe.config","gacutlrc.dll")
    foreach ($item in $gacutilFiles) {
        Copy-Item "$iwsArtifactsDirectory\AtHocENS\ServerObjects\DOTNET\$item" -Destination $hfGacDir -ErrorAction Stop
    }
}

#- Gateways
if ($itemsGateways) {
    Write-Output "`nGateways"
    foreach ($item in $itemsGateways) {Write-Output "`t$item"; Write-Propertiesfile "GATEWAY: $item"}
    Write-Propertiesfile " "
}

#- FilesReplace
if ($itemsToReplace) {
    Write-Output "`nFilesReplace"
    foreach ($item in $itemsToReplace) {
        if (Test-Path "$iwsArtifactsDirectory\$item") {
            New-Item ("$hotfixRootDirectory\$item" | Split-Path) -ItemType Directory -Force | Out-Null
            Write-Output "`tcopying: $iwsArtifactsDirectory\$item  to  $hotfixRootDirectory\$item"
            Copy-Item "$iwsArtifactsDirectory\$item" -Destination "$hotfixRootDirectory\$item" -Force -ErrorAction Stop
        } else {$badReplacePaths += "$item`n"}
    }
    if ($badReplacePaths.length -gt 0) {$errorMessage = "< FilesReplace > : can't find following files in IWS package:`n" + $badReplacePaths; Exit-OnError $errorMessage}
}

#- FilesDelete
if ($itemsToReplace) {
    Write-Output "`nFilesDelete"
    foreach ($item in $itemsToDelete) {Write-Output "`t$item"; Write-Propertiesfile "DELETE: $item"}
    Write-Propertiesfile " "
}

#- SQLfiles
if ($itemsSql) {
    Write-Output "`nSQLfiles"
    $hfSqlDir = "$hotfixRootDirectory\SQL\Install"
    New-Item $hfSqlDir -ItemType Directory -Force | Out-Null
    [int]$i = 0
    foreach($item in $itemsSql) {
        if (Test-Path "$iwsArtifactsDirectory\$item") {
            $i++
            Write-Output ("`tcopying: $iwsArtifactsDirectory\$item  to  $hfSqlDir\" + $i.ToString())
            New-Item ("$hfSqlDir\" + $i.ToString()) -ItemType Directory -Force | Out-Null
            Copy-Item "$iwsArtifactsDirectory\$item" -Destination ("$hfSqlDir\" + $i.ToString()) -ErrorAction Stop
        } else {$badSqlPaths += "$item`n"}
    }
    if ($badSqlPaths.Length -gt 0) {$errorMessage = "< SQL > : can't find following files in IWS package:`n" + $badSqlPaths; Exit-OnError $errorMessage}
}

#- SQLfilesRollB
if ($itemsSqlRollB) {
    Write-Output "`nSQLfilesRollB"
    $hfSqlRbDir = "$hotfixRootDirectory\SQL\Rollback"
    New-Item $hfSqlDir -ItemType Directory -Force | Out-Null
    [int]$i = 0
    foreach($item in $itemsSqlRollB) {
        if (Test-Path "$iwsArtifactsDirectory\$item") {
            $i++
            Write-Output ("`tcopying: $iwsArtifactsDirectory\$item  to  $hfSqlRbDir\" + $i.ToString())
            New-Item ("$hfSqlRbDir\" + $i.ToString()) -ItemType Directory -Force | Out-Null
            Copy-Item "$iwsArtifactsDirectory\$item" -Destination ("$hfSqlRbDir\" + $i.ToString()) -ErrorAction Stop
        } else {$badSqlRbPaths += "$item`n"}
    }
    if ($badSqlRbPaths.Length -gt 0) {$errorMessage = "< SQL > : can't find following files in IWS package:`n" + $badSqlRbPaths; Exit-OnError $errorMessage}
}

#- CustomScript and CustomArgs
if ($itemCustomScript) {
    Write-Output "`nCustomScript"
    $scriptLine = "`t> " + ($itemCustomScript | Split-Path -Leaf) + " $itemCustomArgs"
    Write-Output $scriptLine
    Copy-Item $itemCustomScript -Destination $hotfixRootDirectory -Force -ErrorAction stop
    Write-Propertiesfile ("C.SCRIPT: " + ($itemCustomScript | Split-Path -Leaf))
    if ($itemCustomArgs) {
        Write-Propertiesfile "C.ARGS: $itemCustomArgs"
    }
    Write-Propertiesfile " "
}

#- CustomScriptRollback and CustomArgsRollback
if ($itemCustomScriptRollback) {
    Write-Output "`nCustomScriptRollback"
    $scriptLine = "`t> " + ($itemCustomScriptRollback | Split-Path -Leaf) + " $itemCustomArgsRollback"
    Write-Output $scriptLine
    Copy-Item $itemCustomScriptRollback -Destination $hotfixRootDirectory -Force -ErrorAction stop
    Write-Propertiesfile ("C.SCRIPT.ROLLBACK: " + ($itemCustomScriptRollback | Split-Path -Leaf))
    if ($itemCustomArgsRollback) {
        Write-Propertiesfile "C.ARGS.ROLLBACK: $itemCustomArgsRollback"
    }
    Write-Propertiesfile " "
}

#- ReadmeAppendix
if ($itemReadmeAppendix) {
    Write-Readme "_____________________________________________"
    Write-Readme "ADDITIONAL INFORMATION:"
    Write-Readme " "
    foreach ($line in $itemReadmeAppendix) {
        $line >> $readmeFile
    }
    Write-Readme " "
}

#- Zip up hotfix package
$hotfixFilePath = "$outputDirectory\" + ($hotfixRootDirectory | Split-Path -Leaf) + ".zip"
Write-Output "`nPackaging hotix into $hotfixFilePath..."
Try {[io.compression.zipfile]::CreateFromDirectory($hotfixRootDirectory, $hotfixFilePath)} Catch {Exit-OnError $_}
$numberOfZipfiles = (Get-ChildItem $outputDirectory -Filter '*.zip' | Measure-Object).Count
if ($numberOfZipfiles -gt 1) {Exit-OnError "< numberOfZipfiles >: Working directory needs clean up. Please notify Build&Release team"}


#=== EMAIL NOTIFICATION ===

Send-Email $itemsRecipients
