param (
    [parameter()]
    [Alias('rootdir')]
    [string]$syncdir = $PWD,

    [parameter()]
    [Alias('raw')]
    [switch]$notorganize,
    
    [parameter()]
    [Alias('man')]
    [switch]$help
)


function Play-Sound ([string]$type) {
    $sound = New-Object System.Media.SoundPlayer
    if ($type -eq 'error') {$soundname = "Windows Critical Stop.wav";$sleep = 1}
    elseif ($type -eq 'warning') {$soundname = "Windows Notify.wav";$sleep = 1}
    else {$soundname = "notify.wav";$sleep = 1}
    $sound.SoundLocation = "C:\Windows\Media\$soundname"
    $sound.Play()
    if ($sleep) {sleep -s $sleep}
}

function Prompt-YesNo ([string]$message,[string]$yesDescription,[string]$noDescription) {

    $title = ""
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", $yesDescription
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", $noDescription
    $options = [Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

    switch ($result)
        {
            0 {return $true}
            1 {return $false}
        }
}

function Show-Separator {
    Write-Host "______________________________________________________" -ForegroundColor $script:color_sepr
}

function Get-MenuOption {
    Write-Host "Options: Enter (all), P (photos), V (videos), E (exit)" -ForegroundColor $script:color_prompt
    $key = ""
    while ($key -notin @("Enter","P","V","E")) {
        $key = [System.Console]::ReadKey("NoEcho").key
    }
    switch ($key)
        {
            "Enter" {Write-Host " : all" -ForegroundColor $script:color_option}
            "P" {Write-Host " : photos" -ForegroundColor $script:color_option}
            "V" {Write-Host " : videos" -ForegroundColor $script:color_option}
            "E" {Write-Host " : exit" -ForegroundColor $script:color_option}
        }
    return $key
}

function Create-Syncdir ($syncdir,$device) {
    Write-Host " checkin sync directories on pc..."
    $deviceDir = "$syncdir\$device"
    $pcPulledDir = "$deviceDir\Pulled"
    $pcOrganizedDir = "$deviceDir\Organized"

    if (!((Test-Path $pcPulledDir) -and (Test-Path $pcOrganizedDir))) {
        if (Prompt-YesNo -message "Create sync directories in `"$syncdir`" ?" -yesDescription "Creates 'Pulled' and 'Organized' directories" -noDescription "Exits immediately") {
            $localDirectories = @($syncdir,$deviceDir,$pcPulledDir,$pcOrganizedDir)
            $localDirectories | %{
                if (!(test-path $_)) {
                    Write-Host "  creating: $_..." -ForegroundColor $script:color_detail
                    try {new-item $_ -ItemType directory -Force | out-null}
                    catch {throw $_}
                } else {Write-Host "  found: $_" -ForegroundColor $script:color_detail}
            }
            Remove-Variable localDirectories
        } else {
            Show-Separator
            exit
        }
    }
    return $pcPulledDir,$pcOrganizedDir
}

function Get-RemoteFilesList ($remoteDirectories,$extensions) {
    
    $files = @()

    foreach ($remoteDirectory in $remoteDirectories) {
        foreach ($extension in $extensions) {

        if (!($remoteDirectory.EndsWith('/'))) {$remoteDirectory += "/"}
        if (!($extension.StartsWith('.'))) {$extension = "." + $extension}
        $filesraw = adb shell ls -l $remoteDirectory

            for ($i = 1; $i -lt $filesraw.length; $i++) {
    
                $split = $filesraw[$i].split(' ') | ?{$_.length -gt 0}

                if ($split[0][0] -ne 'd') { 
           
                    $time = $split[6]
                    $name = [regex]::Match($filesraw[$i],"(?<=$time\s).*").Value
                    
                    if ([System.IO.Path]::GetExtension($name) -eq $extension) {

                        $file = New-Object psobject
                        $file | Add-Member NoteProperty Name $name
                        $file | Add-Member NoteProperty FullPath ($remoteDirectory + $name)
                        $file | Add-Member NoteProperty DateTaken ($split[5] + " " +$time)

                        $files += $file
                    }
                }
            }
        }
    }

    return $files
}

function Get-SyncStatus ($remoteFiles,$localFiles) {
### remoteFiles: [object] array, generated in Get-RemoteFilesList
### localfiles: [string] array, local files names only

    $unsynced = 0

    foreach ($file in $remoteFiles) {

        if ($file.name -in $localFiles) {
            $isSynced = $true
        } else {
            $isSynced = $false
            $unsynced++
        }

        $file | Add-Member NoteProperty isSynced $isSynced
    }

    return $unsynced
}

function Show-Stats ($synced,$notsyncedphotos,$notsyncedvideos) {
    Write-Host "______________________________________________`n"
    Write-Host (" photos to sync:`t" + $notsyncedphotos)
    Write-Host (" videos to sync:`t" + $notsyncedvideos)
    Write-Host (" already synced files:`t" + $synced)
    Write-host "______________________________________________`n"
}

function Sync-Files ($files,$pulldir) {
## this needs revision, as adb does not provide errorcodes reliably

    $notsynced = @()
    foreach ($file in $files) {
        if (!$file.isSynced) {
            $notsynced += $file
        }    
    }

    $pullsFailed = 0
    $pullsSuccessful = 0
    $progressTotal = $notsynced.length
    $progressCurrentIndex = 1

    $notsynced | %{
        [int]$progressNew = [int][math]::Truncate($progressCurrentIndex / ($progressTotal /100))
        Write-Progress -Activity "Syncing..." -PercentComplete $progressNew -CurrentOperation "$progressNew% complete"
        Write-Host ("Syncing: " +$_.Name) -ForegroundColor $script:color_detail
        $progressCurrentIndex++
        
        if ((Start-Process adb -ArgumentList ("pull `"" + $_.FullPath + "`" `"$pulldir`"") -NoNewWindow -Wait -PassThru).ExitCode -eq 0) {
            $date = Get-Date $_.DateTaken
            Try {
                (Get-Item ("$pulldir\" + $_.Name) -ErrorAction Stop).CreationTime = $date
                $pullsSuccessful++
            }
            Catch {
                $pullsFailed++
                Write-Host "`t(!)failed" -ForegroundColor $script:color_fail
            }
        } else {
            $pullsFailed++
            Write-Host "`t(!)failed" -ForegroundColor $script:color_fail
        }
    }

    Write-Progress -Activity "Done" -Completed

    return $pullsSuccessful,$pullsFailed
}


#=== BEGIN ===

#--- Help

if ($help) {
    Write-Host "Usage:" -BackgroundColor Black
    Write-Host " -syncdir ('rootdir'): specifies root sync directory for all devices." -BackgroundColor Black
    Write-Host " -notorganize ('raw'): disable organizing of files by 'date created' after sync. All files stay in 'Pulled' directory." -BackgroundColor Black
    Write-Host " -help ('man'):        displays this help." -BackgroundColor Black
    Write-Host ''
    exit
}

#--- Parameters

$photoExtensions = @('.jpg')
$videoExtestions = @('.mp4')
$dateFormat = 'yyyy.MM.dd'

$pcPhoto = @{}
$pcVideo = @{}
$devicePhoto = @()
$deviceVideo = @()

$color_sepr = "DarkGreen"
$color_warn = "Yellow"
$color_succ = "Green"
$color_fail = "Red"
$color_detail = "DarkGray"
$color_prompt = "Cyan"
$color_option = "Magenta"

Write-Host "`nSync directory: $syncdir"
Show-Separator

#--- Wait for device connection
$isDeviceAttached = $false
$isMessage1Shown = $false
$isMessage2Shown = $false
while (!$isDeviceAttached) {
    try {$attachedDevices = adb devices -l}
    catch {throw $_}
  
    if ($attachedDevices.length -gt 3) {
        if (!$isMessage1Shown) {
            Write-Host " (!)More then one device attached" -ForegroundColor $script:color_warn
            $isMessage1Shown = $true
        }
        continue
    }

    if ($attachedDevices[1].length -eq 0) {
        if (!$isMessage2Shown) {
            Write-Host " Please connect device..." -ForegroundColor $color_prompt
            $isMessage2Shown = $true
        }
        adb wait-for-device
    }

    if ($attachedDevices[1] -like '* device *')  {
        $isDeviceAttached = $true
        $serialNumber = ($attachedDevices[1] -Replace '[^a-zA-Z0-9]',':').Split(':')[0]
        $model = ([regex]::Match($attachedDevices[1],'(?<=model\:).*(?=\s)')).value
    }
}

Write-Host " Connected"
Write-Host ("  model: " + $model.replace('_',' ')) -ForegroundColor $script:color_detail
Write-Host "    S/N: $serialNumber" -ForegroundColor $script:color_detail

#--- Look for Sync directories on PC
$syncDirectories = Create-Syncdir $syncdir $model
$pcPulledDir = $syncDirectories[0]
$pcOrganizedDir = $syncDirectories[1]

#--- Look for media files on PC
Write-Output " looking for media files on pc..."
$pcAllMediaRaw = ls $syncdir -Recurse -File
$pcAllMediaRaw | %{
  if (([System.IO.Path]::GetExtension($_.FullName)) -in $photoExtensions) {
    $pcPhoto[$_.name] = $_.fullname
  }
  if (([System.IO.Path]::GetExtension($_.FullName)) -in $videoExtestions) {
    $pcVideo[$_.name] = $_.fullname
  }
}
Remove-Variable pcAllMediaRaw

#--- Look for DCIM directories on device
Write-Output " looking for Camera directories on device..."
$deviceCameraDirectories = @()
adb shell ls /storage/ -R | ?{$_ -like '*/DCIM/Camera:'} | %{$deviceCameraDirectories += ,$_.replace(':','/')}
adb shell ls /sdcard/ -R | ?{$_ -like '*/DCIM/Camera:'} | %{$deviceCameraDirectories += ,$_.replace(':','/')}

if ($deviceCameraDirectories.length -gt 0) {
    $deviceCameraDirectories | %{Write-Host "  $_" -ForegroundColor $script:color_detail}
} else {
    Write-Host " (!)No Camera directories found on device" -ForegroundColor $script:color_warn
    Show-Separator
    exit
}

#--- Look for media files on Device
Write-Output " looking for media files on device..."
$devicePhoto = Get-RemoteFilesList $deviceCameraDirectories $photoExtensions
$deviceVideo = Get-RemoteFilesList $deviceCameraDirectories $videoExtestions
$deviceAllMedia = $devicePhoto.length + $deviceVideo.length
if ($deviceAllMedia -eq 0) {
  Write-Host " (!) no media files found on device" -ForegroundColor $color_warn
  Show-Separator
  exit
} else {
    if ($devicePhoto.length -gt 0) {
        Write-Host ("  found: " + $devicePhoto.length + " photos") -ForegroundColor $color_detail
    }
    if ($deviceVideo.length -gt 0) {
        Write-Host ("  found: " + $deviceVideo.length + " videos") -ForegroundColor $color_detail
    }
    Write-Host ("  TOTAL: " + $deviceAllMedia + " files") -ForegroundColor $color_detail
}

#--- Check sync status
Write-Output " checking synced files..."
$unsyncedPhotos = Get-SyncStatus $devicePhoto $pcPhoto.Keys
$unsyncedVideos = Get-SyncStatus $deviceVideo $pcVideo.Keys
$deviceNotSyncedMedia = $unsyncedPhotos + $unsyncedVideos
$deviceSyncedMedia = $deviceAllMedia - $deviceNotSyncedMedia
if ($deviceNotSyncedMedia -eq 0) {
    Write-Host " (!)all files synced" -ForegroundColor Green
    Show-Separator
    exit
} else {
    Show-Stats $deviceSyncedMedia $unsyncedPhotos $unsyncedVideos
}


#--- Display user options
$option = Get-MenuOption
if ($option -eq "E") {
    Show-Separator
    exit
}

#--- Sync
$pullsSuccessful = 0
$pullsFailed = 0
#- photos
if (($option -eq 'Enter') -or ($option -eq 'P')) {
    Write-Host "______________________________________________"
    Write-Host " Syncing photos..."
    sleep -Milliseconds 500
    $syncResult = Sync-Files -files $devicePhoto -pulldir $pcPulledDir
    $pullsSuccessful += $syncResult[0]
    $pullsFailed += $syncResult[1]
}

#- videos
if (($option -eq 'Enter') -or ($option -eq 'V')) {
    Write-Host "______________________________________________"
    Write-Host " Syncing videos..."
    sleep -Milliseconds 500
    $syncResult = Sync-Files -files $deviceVideo -pulldir $pcPulledDir
    $pullsSuccessful += $syncResult[0]
    $pullsFailed += $syncResult[1]
}

Write-Host "______________________________________________"
Write-Host " Complete`n"
Write-host " files synced: $pullsSuccessful"
Write-Host " files failed: $pullsFailed"
sleep 1

#--- Organizing
Write-Host "______________________________________________"
Write-Host " Organizing..."
if (!$notorganize) {
    Write-Host "______________________________________________"

    $pulledMedia = ls $pcPulledDir -File

    $pulledMedia | %{
        $date = Get-Date ($_.CreationTime) -Format $dateFormat
        if (!(Test-Path $pcOrganizedDir\$date)) {
            New-Item $pcOrganizedDir\$date -ItemType Directory -Force | Out-Null
        }
        if (!(Test-Path ("$pcOrganizedDir\$date\" + $_.Name))) {
            mv ("$pcPulledDir\" + $_.Name) -Destination ("$pcOrganizedDir\$date\" + $_.Name) -ErrorAction Continue
        }
    }
}

Show-Separator
exit

###### Notes ########################
<#
 1. remove 'Syncing:'
 2. implement handling of unauthorized connection to phone
#>