Param (
    [switch]$help,
    [string]$rootDirectory,
    [string]$filesList,
    [string]$pattern
)

function Sign-File ($filePath) {
    $signProcess = Start-Process  signtool -ArgumentList "sign /t http://timestamp.digicert.com /a `"$filePath`"" -NoNewWindow -Wait -PassThru
    return $signProcess.ExitCode
}

if ($help) {
    Write-Host "`n--- Parameters ---"
    Write-Host "<rootDirectory>`t: root folder to look for files to sign"
    Write-Host "<filesList>`t: comma-separated list of full paths"
    Write-Host "<pattern>`t: file mask including asterics (wildcards)"
    sleep -s 5
    exit
}


$scriptDir = Split-Path($MyInvocation.MyCommand.Path)
if (!$rootDirectory) {$rootDirectory = $scriptDir}
$extensions = @("dll","exe","msi")
$allPaths = @()
$exitCode = 0
if ($fileList) {
	write-output "%fileList%`t$fileList"
} else {
	write-output "%rootDirectory% >`t$rootDirectory"
	write-output "%pattern% >`t`t$pattern"
}

#if fileList present, signs only specified files (files must be in the same directory as script)
if ($filesList) {
	foreach ($filePath in $filesList.Split(',')) {
		$allPaths = [array]$allPaths + $filePath
	}

} else {
    foreach ($extension in $extensions) {
        if ($pattern) { #if pattern is present, finds only matching files
            $paths = (Get-ChildItem $rootDirectory -Recurse | ?{$_.Name -like "$pattern.$extension"}).pspath | Convert-Path -ErrorAction SilentlyContinue

        } else { #if no conditions, finds all AtHoc DLLs
            $paths = (Get-ChildItem $rootDirectory -Recurse | ?{$_.Name -like "AtHoc*.$extension"}).pspath | Convert-Path -ErrorAction SilentlyContinue
        }
        $allPaths += $paths
    }
}

if ($allPaths.Length -gt 0) {
    foreach ($path in $allPaths) {
        if ($path.Length -gt 0) {
            Write-Host "`nSigning: $path"
            if (Sign-File $path -gt 0) {
                $exitCode++
            }
        }
    }
} else {
    throw "! CodeSign Failed: Nothing to sign."
}

if ($exitCode -gt 0) {throw "! CodeSign Failed: $exitCode errors, see above for details."}
