function Unmap-Drive {

net use P: /delete /y
}
 
function Map-Drive ([string]$drive) {
 
Unmap-Drive
    
net use P: $drive /u:athoc\bbot F0r3Fr0nt!
}
 
 
# === Makes current date backup in remote location === #
  
Map-Drive -drive \\atstore.athoc.com\Teams\Build.Release\Jenkins.Config.Backup
$jenkinsRootDir = "C:\Jenkins" 
$backupDirPath = "P:\" + (Get-Date -Format yyyy.MM.dd)

if (!(Test-Path $backupDirPath)) {
 
    #creates new backup directory
New-Item $backupDirPath -ItemType Directory

    #mirrors Jenkins directory structure in destination directory
Copy-Item $jenkinsRootDir -Destination $backupDirPath -Filter Directory -Recurse -Force
        
    #copies everything except Jenkins\jobs and Jenkins\logs directories
$jenkinsDirContent = Get-ChildItem $jenkinsRootDir -Recurse

foreach ($item in $jenkinsDirContent) {
        
    if (((Convert-Path $item.pspath) -notlike '*\jobs*') -and ((Convert-Path $item.pspath) -notlike '*\logs*')) {
            
        Copy-Item -Path (Convert-Path $item.pspath) -Destination (Join-Path ($backupDirPath + "\Jenkins") (Convert-Path $item.pspath).Substring($jenkinsRootDir.Length)) -Force
    }
}

    #copies config files only in Jenkins\job directory
$jobsDirContent = Get-ChildItem ($jenkinsRootDir + "\jobs") -Recurse

foreach ($item in $jobsDirContent) {
        
    if ($item.name -eq "config.xml") {
            
        Copy-Item -Path (Convert-Path $item.pspath) -Destination (Join-Path ($backupDirPath + "\Jenkins") (Convert-Path $item.pspath).Substring($jenkinsRootDir.Length)) -Force
    }
}

} else {

Write-Host "Backup directory for current date already exists. Backup will not proceed." -ForegroundColor Red
}


# === Deletes backups that are older then 20 days in remote location === #

$listOfBackups = (Get-ChildItem -Path 'P:\' | ?{$_.PSIsContainer})

$backupsCount = $listOfBackups.length 
  
foreach ($item in $listOfBackups)
{
	if ($backupsCount -gt 3) {
	
		$timespan = (New-TimeSpan -Start $item.CreationTime -End (Get-Date)).Days
		if ($timespan -gt 20)
		{
			Remove-Item -Path ($item.pspath | Convert-Path) -Recurse -Force
		}
		
		$backupsCount--
	}
}


Unmap-Drive