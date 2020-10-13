[CmdletBinding()]

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
    [string]$Workspace,

    [Parameter()]
    [string]$clocVerbose
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
    Write-Output "ToDate:`t$ToDate"
    Write-Output "SvnPath:`t$SvnPath"
    Write-Output "SvnUser:`t$SvnUser"
    Write-Output "SvnPass:`t$SvnPass"
    Write-Output ""
    Write-Output "NodeName:`t$NodeName"
    Write-Output "Workspace:`t$Workspace"
    Write-Output "==============================================`n"

    if (!(Test-Path $script:olderRevisionCheckoutDir) -and !(Test-Path $script:newerRevisionCheckoutDir)) {sleep -Seconds 2}
}


#=== Arguments evaluation ===#

$exitCode = 0
$scriptDir = Split-Path($MyInvocation.MyCommand.Path)
$configFilePath = "$scriptDir\config.xml"
$olderRevisionCheckoutDir = "$scriptDir\olderCheckout"
$newerRevisionCheckoutDir = "$scriptDir\newerCheckout"

Get-SvnPath
Get-DateRange
Display-Parameters

$reportFileName = "LoC_$Product" + "_$FromDate@$ToDate.txt"
#$clocHomeDir = "E:\Cloc_DoNotDelete"

#=== Checkout ===#

Remove-Item $olderRevisionCheckoutDir,$newerRevisionCheckoutDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Output "Checking out older version: > svn checkout $svnPath `"$olderRevisionCheckoutDir`" -r {$FromDate} --username $SvnUser --password $SvnPass --no-auth-cache --non-interactive --trust-server-cert`n"
        $exitCode = (Start-Process svn -ArgumentList "co $svnPath `"$olderRevisionCheckoutDir`" -r {$FromDate} --username $SvnUser --password $SvnPass --no-auth-cache --non-interactive --trust-server-cert" -NoNewWindow -Wait -PassThru).ExitCode
if ($exitCode -ne 0) {
    Exit-OnError "SVN checkout failed, exit code: $exitCode"
}

Write-Output ""
Write-Output "Checking out newer version: > svn checkout $svnPath `"$newerRevisionCheckoutDir`" -r {$ToDate} --username $SvnUser --password $SvnPass --no-auth-cache --non-interactive --trust-server-cert`n"
        $exitCode = (Start-Process svn -ArgumentList "co $svnPath `"$newerRevisionCheckoutDir`" -r {$ToDate} --username $SvnUser --password $SvnPass --no-auth-cache --non-interactive --trust-server-cert" -NoNewWindow -Wait -PassThru).ExitCode
if ($exitCode -ne 0) {
    Exit-OnError "SVN checkout failed, exit code: $exitCode"
}

#=== running Cloc ===#

#Copy-Item "$clocHomeDir\cloc-1.64.exe" -Destination $scriptDir -Force -ErrorAction Stop
if ($clocVerbose -eq 'true') {
  $verboseOutput = " -v=3"
}

Write-Output "`n"
Write-Output "Analyzing Lines of Code statistics: > $scriptDir\cloc-1.72.exe --report-file=$reportFileName --diff `"$olderRevisionCheckoutDir`" `"$newerRevisionCheckoutDir`"$verboseOutput`n"
           $exitCode = (Start-Process "$scriptDir\cloc-1.72.exe" -ArgumentList "--report-file=$reportFileName --diff `"$olderRevisionCheckoutDir`" `"$newerRevisionCheckoutDir`"$verboseOutput" -NoNewWindow -Wait -PassThru -ErrorAction Stop).ExitCode
if ($exitCode -ne 0) {
    Exit-OnError "cloc.exe failed, exit code: $exitCode"
}
