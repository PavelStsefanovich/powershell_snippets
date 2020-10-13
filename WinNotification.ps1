[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

$objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon 

$objNotifyIcon.Icon = "E:\GoogleDrive\stse.pavell\Collections\WindowsCustomization\Icons\clock.ico"
$objNotifyIcon.BalloonTipIcon = "Info" 
$objNotifyIcon.BalloonTipText = "A file needed to complete the operation could not be found.
what if i do several lines?
or will that matter?
how many lines?
how many lines?
how many lines?
how many lines?" 
$objNotifyIcon.BalloonTipTitle = "File Not Found"

$objNotifyIcon.Visible = $True 
$objNotifyIcon.ShowBalloonTip(5000)
$objNotifyIcon.Visible = $false