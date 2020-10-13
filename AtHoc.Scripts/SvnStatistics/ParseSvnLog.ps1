param (
    [parameter()]
    [string]$Product,

    [parameter()]
    [string]$FromDate,

    [parameter()]
    [string]$ToDate,

    [Parameter()]
    [string]$CustomSvnPath,

    [Parameter()]
    [string]$SvnUser,

    [Parameter()]
    [string]$SvnPass, 

    [Parameter()]
    [string]$NodeName,

    [Parameter()]
    [string]$Workspace
)


Function Exit-OnError ([string]$message) {
    Write-Output "`n!!ERROR: $message`n"
    exit 1
}

function Get-DateRange {
    if (!$FromDate) {Exit-OnError "<FromDate> not provided"}
    elseif (!($FromDate -match '^\d\d\d\d\-\d\d\-\d\d$')) {
        Exit-OnError "<FromDate> is in incorrect format: $FromDate. Please use the following format: YYYY-MM-DD"
    }

    if (!$ToDate) {
        $script:ToDate = (get-date -Format yyyy-MM-dd).ToString()
        Write-Output "<ToDate> not provided. Using current date: $ToDate"
    } elseif (!($ToDate -match '^\d\d\d\d\-\d\d\-\d\d$')) {
        Exit-OnError "<ToDate> is in incorrect format: $ToDate. Please use the following format: YYYY-MM-DD"        
    }
}

function Get-SvnPath {
    if ($script:CustomSvnPath -and ($script:CustomSvnPath -like "https://svn.athoc.com/athoc/*")) {
        $script:Product = "Custom"
        $script:SvnPath = $script:CustomSvnPath
    }
    
    if ($script:Product -ne "Custom") {
        [xml]$config = Get-Content $configFilePath -ErrorAction stop
        $script:SvnPath = ($config.Products.Product | ?{$_.name -eq $script:Product}).SvnPath
        if (!$script:SvnPath) {Exit-OnError "Product `"$Product`" not found in config file"}
    }
}

function Display-Parameters {
    Write-Output "`nBUILD PARAMETERS:"
    Write-Output "----------------------------------------------"
    Write-Output "Product:`t$Product"
    Write-Output "FromDate:`t$FromDate"
    Write-Output "ToDate:`t`t$ToDate"
    Write-Output "SvnPath:`t$SvnPath"
    Write-Output "SvnUser:`t$SvnUser"
    Write-Output "SvnPass:`t$SvnPass"
    Write-Output ""
    Write-Output "NodeName:`t$NodeName"
    Write-Output "Workspace:`t$Workspace"
    Write-Output "==============================================`n"
}


#=== Arguments evaluation ===#

$exitCode = 0
$scriptDir = Split-Path($MyInvocation.MyCommand.Path)
$configFilePath = "$scriptDir\config.xml"

Get-SvnPath
Get-DateRange
Display-Parameters

$svnLogFileName = "SvnLog_$Product" + "_$FromDate@$ToDate.xml"
$errorLogFileName = "svnErr.txt"
$reportCsvFileName = "SvnLog_$Product" + "_$FromDate@$ToDate.csv"
$reportTxtFileName = "SvnLog_$Product" + "_$FromDate@$ToDate.txt"

#=== Generating SVN log ===#

       Write-Output "Generating SVN log > svn log $svnPath -r {$FromDate}:{$ToDate} --xml --username $SvnUser --password $SvnPass --no-auth-cache --non-interactive --trust-server-cert`n"
$exitCode = (Start-Process svn -ArgumentList "log $svnPath -r {$FromDate}:{$ToDate} --xml --username $SvnUser --password $SvnPass --no-auth-cache --non-interactive --trust-server-cert" -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$scriptDir\$svnLogFileName" -RedirectStandardError "$scriptDir\$errorLogFileName").ExitCode
if ($exitCode -ne 0) {
    $err = Get-Content "$scriptDir\$errorLogFileName"
    Exit-OnError "SVN operation failed: $err"
}

#=== Parsing SVN log ===#

[xml]$svnLog = Get-Content $svnLogFileName -ErrorAction Stop
$svnLogArray = @()
$reportArray = @()

foreach ($logentry in $svnLog.log.logentry) {$svnLogArray += $logentry}

$svnLogArray | Sort-Object {$_.author} | ForEach-Object {
    $reviewer = ([regex]::Match($_.msg,'(?<=((?i)reviewer(?-i))\:)[a-zA-Z]+')).Value
    $jira = ([regex]::Match($_.msg,'(?<=((?i)jira(?-i))\:)\s?[a-zA-Z]+\-\d+')).Value
    $date = ([regex]::Match($_.date,'\d\d\d\d\-\d\d\-\d\d(?=T)')).Value
    $message
    
    $row = New-Object PSObject
    $row | Add-Member -MemberType NoteProperty -Name "Committer" -Value $_.author
    $row | Add-Member -MemberType NoteProperty -Name "Revision" -Value $_.revision
    $row | Add-Member -MemberType NoteProperty -Name "Reviewer" -Value $reviewer
    $row | Add-Member -MemberType NoteProperty -Name "Jira Issue" -Value $jira

    Write-Output $row    
    
    $row | Add-Member -MemberType NoteProperty -Name "Date" -Value $date
    #$row | Add-Member -MemberType NoteProperty -Name "Commit message" -Value $_.msg.replace("`n"," ")

    $reportArray += $row
}

#=== Output ===#

Write-Output "`nSaving report..."
Write-Output "- $reportCsvFileName"
$reportArray | Export-Csv "$scriptDir\$reportCsvFileName" -NoTypeInformation -Force -ErrorAction Stop
Write-Output "- $reportTxtFileName"
$reportArray | select Committer,Revision,Reviewer,'Jira Issue' | Format-Table -GroupBy Committer | Out-File "$scriptDir\$reportTxtFileName" -Force -ErrorAction Stop