param (
    [string]$javaHome = $(throw "!!ARGUMENT MISSING <javaHome>: path to Java home directory is required"),
    [string]$certificatesDir = $(throw "!!ARGUMENT MISSING <certificatesDir>: path to certificates directory is required"),
    [switch]$forceJavaCertsReplace
)


function Check-IfCertificateExists ($javaHome,$certAlias) {
    $exitCode = (start "$javaHome\bin\keytool.exe" -ArgumentList "-list -v -keystore `"$javaHome\lib\security\cacerts`" -storepass changeit -alias $certAlias -noprompt" -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$scriptDir\null").ExitCode
    rm "$scriptDir\null" -Force -ErrorAction SilentlyContinue
    if ($exitCode -eq 0) {
        Write-Host " <$certAlias> already in keystore"
        return $true
    } else {
        return $false
    }
}

function Remove-ExistingCertificate ($javaHome,$certAlias) {
    Write-Host " Removing certificate: <$certAlias> ..."
    $exitCode1 = (start "$javaHome\bin\keytool.exe" -ArgumentList "-delete -alias $certAlias -storepass changeit -keystore `"$javaHome\lib\security\cacerts`"" -NoNewWindow -Wait -PassThru).ExitCode
    if ($exitCode1 -ne 0) {
        throw ($errorPref + "Failed to remove existing certificate with alias: <$certAlias>")
    }
}

function Install-Certificate ($javaHome,$certificatePath,$certAlias) {
    Write-Host " Installing certificate: <$certAlias> ..."
    $exitCode = (start "$javaHome\bin\keytool.exe" -ArgumentList "-importcert -file `"$certificatePath`" -alias $certAlias -storepass changeit -keystore `"$javaHome\lib\security\cacerts`" -noprompt" -NoNewWindow -Wait -PassThru).ExitCode
    if ($exitCode -ne 0) {
        throw ($errorPref + "Failed to install certificate <$certAlias>: '$certificatePath'")
    }
    Write-Host " <$certAlias> installed succsessfully"
}


$Global:errorPref = "!!ERROR: "
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (!$IsAdmin) {throw ($errorPref + "This script must run as Administrator")}

$Global:scriptDir = $PSScriptRoot
$javaHome = $javaHome.TrimEnd('\/')
$certificatesDir = $certificatesDir.TrimEnd('\/')

Write-Host ("`n(script) " + $MyInvocation.MyCommand.Name + "`n(args)")
Write-Host ("  javaHome:`t`t`t$javaHome")
Write-Host ("  certificatesDir:`t`t$certificatesDir")
Write-Host ("  forceJavaCertsReplace:`t$forceJavaCertsReplace")

#- install wildcard certs to Java CA store
Write-Host "Installing certificates to Java CA store at: '$javaHome\lib\security\cacert'"

Write-Host " - ATHOC.com wildcard ..."
$certAlias = "athoc_wildcard"
if (Check-IfCertificateExists -javaHome "$javaHome" -certAlias $certAlias) {
    if ($forceJavaCertsReplace) {
        Remove-ExistingCertificate -javaHome "$javaHome" -certAlias $certAlias
        Install-Certificate -javaHome "$javaHome" -certificatePath "$certificatesDir\build.athoc.der" -certAlias $certAlias
    }
} else {
    Install-Certificate -javaHome "$javaHome" -certificatePath "$certificatesDir\build.athocdevo.der" -certAlias $certAlias
}

Write-Host " - ATHOCDEVO.com wildcard ..."
$certAlias = "athocdevo_wildcard"
if (Check-IfCertificateExists -javaHome "$javaHome" -certAlias $certAlias) {
    if ($forceJavaCertsReplace) {
        Remove-ExistingCertificate -javaHome "$javaHome" -certAlias $certAlias
        Install-Certificate -javaHome "$javaHome" -certificatePath "$certificatesDir\build.athocdevo.der" -certAlias $certAlias
    }
} else {
    Install-Certificate -javaHome "$javaHome" -certificatePath "$certificatesDir\build.athocdevo.der" -certAlias $certAlias
}
