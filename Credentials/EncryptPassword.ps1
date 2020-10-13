Param (
    [string]$userName,
    [string]$password
)


if (!$userName) {
    $userName = Read-Host -Prompt "Enter username"
}
if (!$password) {
    $securedPassword = Read-Host -AsSecureString -Prompt "Enter password"
} else {
    $securedPassword = ConvertTo-SecureString $password -AsPlainText -Force
}
$encryptedString = ConvertFrom-SecureString $securedPassword -Key (1..16)
$encryptedStringFileName = "$userName.Encrypt.Passw.txt"

Get-ChildItem $encryptedStringFileName -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
New-Item $encryptedStringFileName -ItemType File
Add-Content $encryptedStringFileName -Value $encryptedString


exit

function Create-Credential ([string]$username,[string]$encryptedString) { #create Powershell credential object from username and password as secured string
    $securedPassword = ConvertTo-SecureString $encryptedString -Key (1..16)
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $securedPassword
    return $credential
}