$runDir = "E:\GoogleDrive"
$jokes = cat $runDir\Jokes.txt
$newsequence = ""
$jokesTable = @{}
$jokesCount = 0
$labeltext = ""

if (Test-Path $runDir\sequence.txt) {
    $sequence = (cat $runDir\sequence.txt -TotalCount 1).split(',')
    if ($sequence[0].Length -eq 0) {$sequence = @()}
} else {
    $sequence = @()
}

for ($i = 0; $i -lt $jokes.Length; $i++) {
    if ($jokes[$i] -like '__________*') {
        $jokesCount ++
        $jokesTable.Add($jokesCount,$i+1)        
    }
}

if ($sequence.Length -gt 0) {
    $currentJokeIndex = [int]$sequence[0]
    if ($sequence.Length -gt 1) {
        $i = 1
        do {
            $newsequence += ($sequence[$i] + ",")
            $i++
        } until ($i -eq $sequence.Length)
    }
} else {
    $randArray = Get-Random -Count $jokesCount -InputObject (1..$jokesCount)
    $currentJokeIndex = $randArray[0]
    for ($i = 1; $i -lt $randArray.length; $i++) {
        $newsequence += ($randArray[$i].ToString() + ",")
    }
}

$newsequence.TrimEnd(',') | Out-File $runDir\sequence.txt -Encoding ascii
$lineStart = $jokesTable.$currentJokeIndex
$lineEnd = $jokesTable.($currentJokeIndex + 1) - 2
if (!$lineEnd) {$lineEnd = $jokes.Length - 1}
$jokeOfTheDay = $jokes[$lineStart..$lineEnd]
$jokeOfTheDay | %{$labeltext += "$_`n"}

### Display

Add-Type -AssemblyName PresentationFramework
$ButtonType = [System.Windows.MessageBoxButton]::OK

#$MessageIcon = [System.Windows.MessageBoxImage]::Information
#[System.Windows.MessageBox]::Show($labeltext,"Joke of the day",$ButtonType,$MessageIcon)

[System.Windows.MessageBox]::Show($labeltext," Joke of the day",$ButtonType)
