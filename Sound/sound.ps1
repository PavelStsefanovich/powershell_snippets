function Play-Sound ([string]$type) {
    $sound = New-Object System.Media.SoundPlayer
    if ($type -eq 'error') {$soundname = "Windows Critical Stop.wav";$sleep = 1}
    elseif ($type -eq 'warning') {$soundname = "Windows Notify.wav";$sleep = 1}
    else {$soundname = "notify.wav";$sleep = 1}
    $sound.SoundLocation = "C:\Windows\Media\$soundname"
    $sound.Play()
    if ($sleep) {sleep -s $sleep}
}

$sound = New-Object System.Media.SoundPlayer
$sound.SoundLocation = 'C:\Windows\Media\notify.wav'
write-warning "This is warning sound!"
$sound.Play()
