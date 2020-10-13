[CmdletBinding(HelpUri = "https://ewiki.athoc.com")]
Param (
    [string]$CertFilename = 'AtHoc_Code_Signing_exp_Sep_2022.pfx',
    [string]$CertPassw,
    [string]$WORKSPACE = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$errorPref = "!!ERROR:"

$CertFilepath = (Resolve-Path (Join-Path $PSScriptRoot $CertFilename)).Path
if ($CertPassw) {
    $securePassw = ConvertTo-SecureString $CertPassw -AsPlainText -Force
}
else {
    throw "$errorPref Password is not profided for .pfx certificate."
}

write-host "Updating registry (win update 3000850 issu: https://support.microsoft.com/en-ca/help/3000850/november-2014-update-rollup-for-windows-rt-8-1-windows-8-1-and-windows)"
New-ItemProperty HKLM:/SOFTWARE/Microsoft/Cryptography/Protect/Providers/df9d8cd0-1501-11d1-8c7a-00c04fc297eb/ -Name ProtectionPolicy -Value 1 -PropertyType 'DWord' -ErrorAction SilentlyContinue | Out-Null

write-host "Installing certificate"
try {
	Import-PfxCertificate -FilePath "$CertFilepath" -CertStoreLocation Cert:/CurrentUser/My/ -Password $securePassw -ErrorAction Stop | out-null
}
catch {
    Write-Warning "Failed to install Codesign certificate: '$CertFilepath'"
	rm $CertFilepath -force
    throw $_
}

rm $CertFilepath -force

