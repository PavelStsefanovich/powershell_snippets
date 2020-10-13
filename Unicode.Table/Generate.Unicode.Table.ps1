$max = 65535
$line = "8200:`t"
$resultTable = @()
$i = 0

8200..11250 | %{
    if ($i -gt 49) {$i = 0; $resultTable += $line; $line; $line = "$_`:`t"}
    $line += [char]$_
    $i++
}

$resultTable > "Unicode.Table2.txt"
"=========================================================="
$resultTable