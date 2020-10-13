param (
    [parameter(Mandatory=$true, Position=0)]
    [string]$Product,

    [parameter()]
    [switch]$ReleaseRun,

    [parameter()]
    [string]$FromDate,

    [parameter()]
    [string]$ToDate,

    [Parameter()]
    [string]$username,

    [Parameter()]
    [string]$extensionsListPath
)

Function Exit-OnError ([string]$message) {
    Write-Output $message
    exit 1
}

function Get-Credential {
    if (!$username) {
        $securedPassword = ConvertTo-SecureString (Get-Content "$scriptDir\$encryptedStringFileName") -Key (1..16)
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securedPassword)
        $script:password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $script:username = ($encryptedStringFileName.Split('.'))[0]
    } else {
        $securedPassword = Read-Host -Prompt "Enter password for user $username" -AsSecureString
    
    }
    $script:credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $securedPassword
}

function Get-DateRange {
    if (!$FromDate) {
        Write-Output "`"FromDate`" not provided. Setting to last release date..."
        
        if ($csvData.'Release Date') {
            if ($csvData.length) {
                $i = $csvData.length - 1
                while ($csvData[$i].length -eq 0) {
                    $i--
                }
            } else {
                $i = 0
            } 
            [string]$date = ($csvData[$i].'Release date')
            if ($date -match '^\d\d\d\d\-\d\d\-\d\d$') { # e.g. yyyy-mm-dd
                    $script:FromDate = $date
                } elseif ($date -match '^\d\d\/\d\d\/\d\d\d\d$') { # e.g. mm/dd/yyyy
                    $script:FromDate = $date.Split('/')[2] + "-" + $date.Split('/')[0] + "-" + $date.Split('/')[1]
                } elseif ($date -match '^\d\d\d\d\/\d\d\/\d\d$') { # e.g. yyyy/mm/dd
                    $script:FromDate = $date -replace ('/','-')
                } else {
                    Exit-OnError "`"FromDate`" is in incorrect format in .csv file: $FromDate. Make sure it follows format: YYYY-MM-DD"
                }
             
        } else {
            Exit-OnError "No `"FromDate`" specified and there is no $statCsvFilePath, or file is empty"
        }

    } elseif (!($FromDate -match '^\d\d\d\d\-\d\d\-\d\d$')) {
        Exit-OnError "`"FromDate`" is in incorrect format: $FromDate. Please use the following format: YYYY-MM-DD"        
    }

    if (!$ToDate) {
        Write-Output "`"ToDate`" not provided. Setting to current date..."
        $script:ToDate = (get-date -Format yyyy-MM-dd).ToString()
        Write-Output "No `"ToDate`" specified, using current date: $ToDate"
    } elseif (!($ToDate -match '^\d\d\d\d\-\d\d\-\d\d$')) {
        Exit-OnError "`"ToDate`" is in incorrect format: $ToDate. Please use the following format: YYYY-MM-DD"        
    }
}

function Get-SvnPath {
    if (Test-Path $propertiesFilePath) {
        $script:svnPath = ((Get-Content $propertiesFilePath | ?{$_ -match 'branch.path'}).Split('='))[1]
        if ($svnPath.Length -eq 0) {
            Exit-OnError "Can not read svn path from properties file: $propertiesFilePath"
        }
    } else {
        Exit-OnError "Can not find properties file: $propertiesFilePath"
    }
}

function Get-PreviousStats {

    if (Test-Path $statCsvFilePath) {
        $script:csvData = Import-Csv $statCsvFilePath
    } else {
        Exit-OnError "Can not find stats file: $statCsvFilePath"
    }
}

function Get-IncludedExtensions {
    $script:includedExtensions = @()
    $extensionsList = Get-Content $extensionsListPath
    foreach ($extension in $extensionsList) {
        $script:includedExtensions += ("*." + $extension)
    }
}

function Display-Parameters {
    Write-Output "`nBUILD PARAMETERS:"
    Write-Output "-------------------------"
    Write-Output "Product:`t$Product"
    Write-Output "FromDate:`t$FromDate"
    Write-Output "ToDate:`t$ToDate"
    if ($ReleaseRun) {
        Write-Output "ReleaseRun:`t$ReleaseRun"
    }
    Write-Output "Description:`t$Product, $FromDate to $ToDate"
    Write-Output "workingDir:`t$workingDir"
    Write-Output "scriptDir:`t$scriptDir"
    Write-Output "SourceCodeDir: $sourceCodeDir"
    Write-Output "svnPath:`t$svnPath"
    Write-Output "=========================`n"
}

function Display-Results {
    Write-Output "`nRESULTS:"
    Write-Output "-------------------------"
    Write-Output "Files: (total files: $filesTotal)"
    Write-Output " - added:`t$filesAdded"
    Write-Output " - deleted:`t$filesDeleted"
    Write-Output " - modified:`t$filesModified"
    Write-Output "Lines:"
    Write-Output " - added:`t$linesAdded"
    Write-Output " - deleted:`t$linesDeleted"
    Write-Output " - modified:`t$linesModified"
    Write-Output "========================="
}


#=== Arguments evaluation ===#

$exitCode = 0
$workingDir = $PWD
$sourceCodeDir = "$workingDir\$Product"
$scriptDir = Split-Path($MyInvocation.MyCommand.Path)
$encryptedStringFileName = "bbot.Encrypt.Passw.txt"
$extensionsListFileName = "includedFileExtensions.txt"
$diffFilePath = "$workingDir\SvnDiffFull.log"
$propertiesFilePath = "$scriptDir\$Product\properties"
$statCsvFilePath = "$scriptDir\$Product\$Product.LinesOfCode.Stats.csv"
$statCsvFileName = Split-Path $statCsvFilePath -Leaf
Get-SvnPath
Get-PreviousStats
Get-Credential
Get-DateRange
Display-Parameters


#=== SVN diff output generation ===#

    #--- checkout
if ($ReleaseRun) {
    if (Test-Path $sourceCodeDir) {
        Write-Output "Cleaning up for release run..."
        Remove-Item $sourceCodeDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if (Test-Path $sourceCodeDir) {
    Set-Location $sourceCodeDir
    Start-Process svn -ArgumentList "cleanup" -NoNewWindow -Wait
    Write-Host "Working copy found. Updating...`n> svn update --username $username --password $password --depth infinity --force"
    $exitCode = (Start-Process svn -ArgumentList "up --username $username --password $password --depth infinity --force" -NoNewWindow -Wait -PassThru).ExitCode
    Set-Location $scriptDir
} else {
    New-Item $sourceCodeDir -ItemType Directory
    Write-Host "Working copy not found. Checkout new copy...`n> svn checkout $svnPath `"$sourceCodeDir`" --username $username --password $password --no-auth-cache --non-interactive --trust-server-cert"
    $exitCode = (Start-Process svn -ArgumentList "co $svnPath `"$sourceCodeDir`" --username $username --password $password --no-auth-cache --non-interactive --trust-server-cert" -NoNewWindow -Wait -PassThru).ExitCode
}
if ($exitCode -ne 0) {
    Exit-OnError "!! SVN checkout failed, exit code: $exitCode"
}

    #--- total files count
Write-Output "Counting files..."

if ($extensionsListPath) {
    Get-IncludedExtensions
} elseif (Test-Path "$scriptDir\$extensionsListFileName") {
    $extensionsListPath = "$scriptDir\$extensionsListFileName"
} else {
    $includedExtensions = @('*.cs,*.config,*.js,*.pl,*.rc,*.java,*.css,*.xml,*.csproj,*.sql,*.asp,*.aspx,*.asa,*.html,*.htm,*.cshtml,*.vbp,*.cls,*.bas,*.bat,*.xslt,*.cpp,*.c,*.h,*.hpp,*.sln'.Split(','))
}

$filesTotal = (Get-ChildItem $sourceCodeDir -Recurse -Include $includedExtensions | Measure-Object).Count

    #--- diff
if (Test-Path $diffFilePath) {
    Remove-Item $diffFilePath -Force
}
Set-Location $sourceCodeDir
Write-Output "Generating diff...`n> svn diff -x --ignore-all-space -r{$FromDate}:{$ToDate} $svnPath"
$diffOutput = Start-Process svn -ArgumentList "diff -x --ignore-all-space -r{$FromDate}:{$ToDate} $svnPath" -NoNewWindow -Wait -RedirectStandardOutput $diffFilePath
Set-Location $scriptDir
$diffOutput = Get-Content $diffFilePath


#=== LinesOfCode stats calculation ===#

Write-Output "Analyzing LinesOfCode stats..."

[int]$filesDeleted = 0
[int]$filesAdded = 0
[int]$filesModified = 0

[int]$linesDeleted = 0
[int]$linesAdded = 0
[int]$linesModified = 0


[long]$currentLine = 0
[long]$hunkEndLine = 1
[int]$progress  = 0
[long]$diffOutputLength = $diffOutput.Length

while ($currentLine -lt $diffOutputLength) {
    [int]$newprogress = [int][math]::Truncate($currentLine / ($diffOutputLength /100))
    if ($newprogress -gt $progress) {
        $progress = $newprogress
        Write-Output "$progress% .."
    }    

    while (($hunkEndLine -lt $diffOutputLength)-and !($diffOutput[$hunkEndLine].StartsWith('Index: '))) {
        $hunkEndLine++
    }

    if (($diffOutput[$currentLine + 2].Contains('(nonexistent)')) -or ($diffOutput[$currentLine + 2].Contains('(revision 0)'))) {
        $filesAdded++
    }

    $currentLine+=4

    for ([long]$i = $currentLine; $i -lt $hunkEndLine; $i++) {
        if ($diffOutput[$i].StartsWith('@@')) {
            $hunkRangeInfo = $diffOutput[$i].Split(' ')
            if (($hunkRangeInfo[1] -like '-1,*') -and ($hunkRangeInfo[2] -eq '+0,0')) {
                $filesDeleted++
            } else {
                $filesModified++
            }

            $origLines = [int]($hunkRangeInfo[1].Split(','))[1]
            $newLines = [int]($hunkRangeInfo[2].Split(','))[1]

            [int]$lineDifference = $newLines - $origLines
            if ([math]::Sign($lineDifference) -eq 1) {
                $linesAdded += $lineDifference
                $linesModified += ($newLines - $lineDifference)
            } elseif ([math]::Sign($lineDifference) -eq -1) {
                $lineDifference *= -1
                $linesDeleted += $lineDifference
                $linesModified += ($origLines - $lineDifference)
            } else {
                $linesModified += $lineDifference
            }
        }
    }

    $currentLine = $hunkEndLine
    $hunkEndLine++
} 


#=== Displaying and Saving results ===#

Display-Results
Display-Parameters

$newRow = New-Object PsObject -Property @{ 'From Date' = $FromDate ; 'Release Date' = $ToDate ; 'Lines Added' = $linesAdded ; 'Lines Deleted' = $linesDeleted; 'Lines Modified' = $linesModified; 'Files Added' = $filesAdded; 'Files Deleted' = $filesDeleted; 'Files Modified' = $filesModified; 'Files TOTAL' = $filesTotal}
$csvData = [array]$csvData + $newRow
Remove-Item "$statCsvFilePath.bak" -Force -ErrorAction SilentlyContinue
Rename-Item $statCsvFilePath -NewName ($statCsvFileName + ".bak") -Force
New-Item $statCsvFilePath -ItemType File -Force | Out-Null
$csvData | Export-Csv $statCsvFilePath -NoTypeInformation

if ($ReleaseRun) {
    Start-Process svn -ArgumentList "upgrade" -NoNewWindow -Wait
    Write-Host "Saving stats file to source control...`n> svn commit -F $statCsvFilePath --force-log --username $username --password $password"   
    $exitCode = (Start-Process svn -ArgumentList "commit -F $statCsvFilePath --force-log --username $username --password $password" -NoNewWindow -Wait -PassThru).ExitCode
}
if ($exitCode -ne 0) {
    Exit-OnError "!! SVN commit failed, exit code: $exitCode"
}