function Show-Step ($message) {
    Write-Host " - $message" -ForegroundColor Gray
}

function Show-Warning ($message) {
    Write-Host " (!) $message" -ForegroundColor Yellow
}

Show-Step 'disabling UseWUServer'
sp HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\ -Name UseWUServer -Value 0

Show-Step 'disabling fsutil'
$os = (Get-WMIObject win32_operatingsystem).name
if ($os -like '*Server 2012*') {
    fsutil behavior set DisableDeleteNotify 1
} elseif ($os -like '*Server 2016*') {
    fsutil behavior set DisableDeleteNotify NTFS 1
    fsutil behavior set DisableDeleteNotify ReFS 1
} else {
    Show-Warning "Not supported OS: $os" 
}