$recipients = @("someone@blackberry.com","anotherone@blackberry.com")
$file = ".\attachment.file"
$text = @"
To be happy:
Copy this letter 10 times and send away.
To be unhappy:
Forget about this.
"@
$textFile = ".\emailInline.txt"

Write-Output "Sending Email notification to: $recipients"
$SMTPServer = "atcasht.athoc.com"
#$attachment = New-Object Net.Mail.Attachment($file)
$message = New-Object Net.Mail.MailMessage
$smtp = New-Object Net.Mail.SmtpClient($SMTPServer, 25)
$message.From = "br@athoc.com"
foreach ($item in $recipients) {$message.To.Add($item)}
$message.Subject = "Letter of Happiness"
#$smtp.EnableSSL = $true
#$smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password);
$message.IsBodyHTML = $true
$message.Body = Get-Content $textFile | Out-String
#message.Body = $text
#$message.Attachments.Add($attachment)
$smtp.Send($message)