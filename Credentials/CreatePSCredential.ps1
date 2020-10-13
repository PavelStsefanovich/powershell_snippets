Param (
    [Parameter(Mandatory=$true)]
    [string]$encryptedStringFileName
)

$securedPassword = ConvertTo-SecureString (Get-Content $encryptedStringFileName) -Key (1..16)
$username = ($encryptedStringFileName.Split('.'))[0]
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $securedPassword
