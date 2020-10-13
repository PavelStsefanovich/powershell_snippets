param(
    [string]$javaRoot
)

$ErrorActionPreference = "Stop"

if (!$javaRoot) {
    $uninstallKey = 'HKLM:/SOFTWARE/Microsoft/Windows/CurrentVersion/Uninstall'
    $installedSoftware = gp (ls $uninstallKey).name.Replace('HKEY_LOCAL_MACHINE','HKLM:')
    $javaRoot = ($installedSoftware | ?{(($_.displayname -like '*java*') -and ($_.displayname -notlike '*SE Development*'))}).InstallLocation
}

$javaPath = (Resolve-Path ($javaRoot.TrimEnd('\/') + "\bin\java.exe")).Path

if ($javaPath -is [array]) {
    throw "More than one Java installation found. Please specify target installation root directory with -javaRoot parameter"
}

$jenkinsSlaveConfig = (Resolve-Path (((gps *jenk*slave*).Path | Split-Path) + "\jenkins-slave.xml")).Path

try {
    (cat $jenkinsSlaveConfig -Raw) -replace '(?<=\<executable\>).*(?=\<\/executable\>)',$javaPath | Set-Content $jenkinsSlaveConfig -Force
    Write-Host " > Jenkins config updated successfully"
} catch {
    throw $_
}

Write-Host " > Restarting Jenkins service ..."

try {
    gsv *jenk*slave* -ErrorAction Stop | Restart-Service
    Write-Host "  Done."
} catch {
    throw $_
}