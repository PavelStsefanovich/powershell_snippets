PS C:\> $my_secure_password = convertto-securestring "P@ssW0rD!" -asplaintext -force
Create a secure string using the Read-Host cmdlet:

PS C:\> $my_secure_password = read-host -assecurestring
Save an encrypted string to disc:

PS C:\> $my_encrypted_string = convertfrom-securestring $my_secure_password -key (1..16)
PS C:\> $my_encrypted_string > password.txt




Read an encrypted string from disc and convert back to a secure string:

PS C:\> $my_secure_password = convertto-securestring (get-content password.txt) -key (1..16)


_______________________
PSCredential

1.
$buildUser = "bbot"
$buildPassw = Get-Content "$currentDir\VM.buildUserPassw.txt" | ConvertTo-SecureString -Key (1..16)
$cred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $buildUser, $buildPasswssw

2.
$secpasswd = ConvertTo-SecureString "PlainTextPassword" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ("username", $secpasswd)

3.
$mycredentials = Get-Credential		(non-interactive)

_______________________
SecureString -> plain text

$securePass = Read-Host "sa password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
$DBPasswordSA = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)	