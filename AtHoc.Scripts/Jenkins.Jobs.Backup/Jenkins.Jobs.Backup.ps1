[CmdletBinding()]
param (
    [string]$JenkinsRootDir = 'C:\Program Files (x86)\Jenkins',
    [string]$BackupRootDir = $PWD.Path,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$JenkinsJobsDir = "$JenkinsRootDir\jobs"
$BackupDir = "$BackupRootDir\Jenkins.Jobs.Backup"
$zipFilepath = "$BackupRootDir\Jenkins.Jobs.Backup.zip"

if (Test-Path $BackupDir) {
    if ($Force) {
        rm $BackupDir -Force -Recurse -ErrorAction Stop
    } else {
        throw "Directory already exists: $BackupDir"
    }
}
mkdir $BackupDir -Force | Out-Null

if (Test-Path $zipFilepath) {
    if ($Force) {
        rm $zipFilepath -Force -ErrorAction Stop
    } else {
        throw "Backup file already exists: $zipFilepath"
    }
}

$myJobs = @('Mac*','DSW*','MobileAp*','cloud*','chef*','br*','athocdevo_Boo*','Hock*','mapats*','Install_*')
$jobDirs = @()
foreach ($item in $myJobs) {$jobDirs += ls $JenkinsJobsDir -Directory | ?{$_.name -like $item}}
foreach ($dir in $jobDirs) {
    $backupJobDir = (mkdir "$BackupDir\$($dir.Name)" -Force).FullName
    (ls $dir.fullname -Filter 'config.xml').FullName | cp -Destination $backupJobDir -Force
}

[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) | Out-Null
[io.compression.zipfile]::CreateFromDirectory($BackupDir, "$BackupRootDir\Jenkins.Jobs.Backup.zip", "Optimal", $true) 