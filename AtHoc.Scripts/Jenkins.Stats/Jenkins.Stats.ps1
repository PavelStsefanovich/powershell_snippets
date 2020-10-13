[CmdletBinding(HelpUri = "https://ewiki.athoc.com/display/BR/Jenkins.Stats.ps1",DefaultParameterSetName='argumentLine')]
param (
    [Parameter(ParameterSetName='argumentLine', Mandatory=$True)]
    [string]$JenkinsUrl,

    [Parameter(ParameterSetName='argumentLine', Mandatory=$True)]
    [string]$JenkinsUser,

    [Parameter(ParameterSetName='argumentLine', Mandatory=$True)]
    [string]$JenkinsApiToken,

    [Parameter(ParameterSetName='propertiesFile', Mandatory=$True)]
    [string]$PropertiesFilepath,

    [Parameter()]
    [string]$ViewName,

    [Parameter()]
    [switch]$CI
)


function Resolve-Filepath ([string]$path,[string]$workspacedir,[string]$scriptDir) {
    if ($path -match '^\.[\\\/]\w+') {
        $resolvedPath = $scriptDir.TrimEnd('\') + $path.TrimStart('.')
    } elseif ($path -match '^[a-zA-Z]\:[\\\/]\w+') {
        $resolvedPath = $path
    } else {
        $resolvedPath = "$workspacedir\$path"
    }
    return $resolvedPath
}

function Get-RestApi ($url,$webClient) {
    try {
        Add-Type -AssemblyName System.Web.Extensions
        $json = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
        $json.MaxJsonLength = 104857600
        $jsonRaw = $wc.DownloadString($url)
        $jsonObject = $json.Deserialize($jsonRaw, [System.Object])
    } catch {
        throw $_
    }
    return $jsonObject
}

function RunGroovyScriptOnJenkinsServer ($jenkinsUrl, $groovyScript, $wc) {
    $url = $jenkinsUrl + "/scriptText"
    $nvc = New-Object System.Collections.Specialized.NameValueCollection
	$nvc.Add("script", $groovyScript);
    try {
	    $byteRes = $wc.UploadValues($url,"POST", $nvc)
    } catch {
        throw $_
    }
	$res = [System.Text.Encoding]::UTF8.GetString($byteRes)
    return $res
}

function Format-Out ([pscustomobject]$object,[string]$format,[string]$spacing) { # (ps) this is to be developed further: add more formats
    $properties = [string[]]($object.SyncRoot | Get-Member -MemberType NoteProperty).Name
    if (!$spacing) {$spacing = "   "}

    if ($format -eq 'table') {
        $header = $separator = " "
        $columnsWidth = @{}

        #- print header
        foreach ($property in $properties) {
            if ($object.$property) {
                if ($object.$property -is [array]) {
                    $maxValueLength = ([string[]]($object.$property) | ?{$_.length -gt 0} | sort {$_.length}  -Descending)[0].length
                } else {
                    $maxValueLength = $object.$property.length
                }
            } else {
                $maxValueLength = 0
            }
            switch ($property.length -gt $maxValueLength) {
                $True { $width = $property.length; break }
                $false { $width = $maxValueLength }
            }

            $columnsWidth.Add($property,$width)
            $header += ($property + (" " * ($columnsWidth.$property - $property.length)) + $spacing)
            $separator += (("-" * $columnsWidth.$property) + $spacing)
        }
        Write-Host $header
        Write-Host $separator

        foreach ($item in $object) {        
            $outline = " "
            foreach ($property in $properties) {
                if ($item.$property) {
                    $outline += ([string]$item.$property + (" " * ($columnsWidth.$property - [string]$item.$property.length)) + $spacing)
                } else {
                    $outline += (" " * $columnsWidth.$property) + $spacing
                }
            }
            Write-Host $outline
        }

    } else {
        Write-Warning "Format-Out: Unknown format '$format'"
    }
}


#=== INITIALISATION

$timeStart = Get-Date
$ErrorActionPreference = "Stop"
$Global:errorPref = "!!ERROR:"
$scriptDir = $PSScriptRoot
if (!$JenkinsApiToken) {
    if ($PropertiesFilepath) {
        $properties = ConvertFrom-StringData (gc (Resolve-Filepath $PropertiesFilepath $scriptDir $scriptDir) -Raw)
        if ($properties.JenkinsUrl) {$JenkinsUrl = $properties.JenkinsUrl} else {throw "$errorPref Argument missing: <JenkinsUrl>"}
        if ($properties.JenkinsUser) {$JenkinsUser = $properties.JenkinsUser} else {throw "$errorPref Argument missing: <JenkinsUser>"}
        if ($properties.JenkinsApiToken) {$JenkinsApiToken = $properties.JenkinsApiToken} else {throw "$errorPref Argument missing: <JenkinsApiToken>"}
    } else {
        throw "$errorPref Jenkins Api Token not provided"
    }
}

#- construct WebClient object
$token = $JenkinsUser + ":" + $JenkinsApiToken
$tokenBytes=[System.Text.Encoding]::UTF8.GetBytes($token)
$base64 = [System.Convert]::ToBase64String($tokenBytes)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("Authorization", "Basic $base64")

#- declare constants
$jobDirExclude = @('.chef')
$jobsStatusFile = "$scriptDir\JobsStatus.csv"
$orphanedJobDirectoriesFile = "$scriptDir\OrphanedJobDirectories.txt"

#=== BEGIN

Write-Host "`n"

#- get list of existing jobs
if ($ViewName) {
    Write-Host "Getting list of jobs in view <$ViewName> ..."
    $url = "$JenkinsUrl/view/$ViewName/api/json"
    $jobList = (Get-RestApi $url $wc).jobs.name
} else {
    Write-Host "Getting list of all jobs ..."
    $url = "$JenkinsUrl/api/json?pretty=true"
    $jobList = (Get-RestApi $url $wc).jobs.name
}

#- analyse jobs status
Write-Host "Analyzing Jobs ..."
$jobsStatus = @()
$progressTotal = $jobList.Length
$progress = 0

foreach ($jobname in $jobList) {

    #- display progress
    $progress++
    [int]$newprogressPercent = [int][math]::Truncate($progress / ($progressTotal /100))
    if ($newprogressPercent -gt $progressPercent) {
        $progressPercent = $newprogressPercent
        if ($CI) {
            Write-Host " $progressPercent%"
        } else {
            $progressLine = "  $progressPercent% ["
            $progressLine += ([string][char]1000 * ($progressPercent / 2)) + ("." * (50 - $progressPercent / 2)) + "]`r"
            Write-Host $progressLine -NoNewline
        }
    }

    #- get job object
    $url = "$JenkinsUrl/job/$jobname/api/json"
    $jobObject = Get-RestApi $url $wc
    
    #- get builds for job
    $buildList = $jobObject.builds.number
    $pinnedBulids = @()
    $buildList | %{
        $url = "$JenkinsUrl/job/$jobname/$_/api/json"
        if ((Get-RestApi $url $wc).keepLog -eq 'True') {
            $pinnedBulids += $_
        }
    }
     
    $jobStatusLine = [pscustomobject]@{
        Jobname = $jobname
        NumberOfBuilds = [string]$buildList.count
        PinnedBuilds = $pinnedBulids -join(',')
    }

    $jobsStatus += $jobStatusLine
}
Write-Host " 100%`n"
$jobsStatus | Export-Csv $jobsStatusFile -NoTypeInformation -Force

#- display analysis resulst
Format-Out $jobsStatus -format table

#- find orphaned job directories
if (!$ViewName) {
    Write-Host ""

    #- get list of directories in JENKINS_HOME/jobs
    $groovyScript = @"
jenkinsHome = System.getenv("JENKINS_HOME")//.replace("\\", "/")
new File(jenkinsHome + "\\jobs").eachDir()
{ dir ->  
   println(dir.getPath())  
}
"@    
    $runScriptResult = RunGroovyScriptOnJenkinsServer -jenkinsUrl "$jenkinsUrl" -groovyScript $groovyScript -wc $wc

    $jobDirectories = @{}
    $runScriptResult.split("`n").trim() | %{
        $dirName = $_ | Split-Path -Leaf -ErrorAction SilentlyContinue
        if ($dirName) {
            if ($dirName -notin $jobDirExclude) {
                $jobDirectories.Add($dirName,$_)
            }
        }
    }

    Write-Host "Looking for orphaned directories ..."
    $orphanedJobDirectories = @()

    $jobDirectories.GetEnumerator().name | %{
        if ($_ -notin $jobList) {
            $orphanedJobDirectories += $jobDirectories.$_
        }
    }
    $orphanedJobDirectories | %{Write-Host "  $_"}
    $orphanedJobDirectories | Out-File $orphanedJobDirectoriesFile -Force -Encoding ascii
}

#- time elapsed
$timeEnd = Get-Date
Write-Host ("`nDone in " + [int](New-TimeSpan $timeStart $timeEnd).TotalMinutes + " minutes`n")