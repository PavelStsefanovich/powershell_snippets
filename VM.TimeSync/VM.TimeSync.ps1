
 $ntpServer = $args[0];
if ( !$ntpServer )
 {
 Write-Host "Message: Can't find ""ntpServer"" argument. Check documentation.";
 exit 1;
 }
$ntpQuery  =  Invoke-Expression "w32tm /monitor /computers:$ntpServer" | Out-String;
$findSkew = [regex]"(?:NTP\: )(?<Value>/?[^s]+)";
If (($ntpQuery -match $findSkew))
{
    $ntpToSolarSkew = $Matches['Value'];
    $Error.Clear();
    try 
    {
        $remoteServerTime = Get-WmiObject Win32_UTCTime -ComputerName ${IP} -Credential ${CREDENTIAL};
    }
    catch 
    {
        Write-Host "Message: Unable to Get-WmiObject Win32_UTCTime on remote client. $($Error[0])";
        exit 1;
    }
    $localTime = $(Get-Date).ToUniversalTime();
    $remoteToSolarSkew = New-TimeSpan $localTime $(Get-Date -year $remoteServerTime.Year -month $remoteServerTime.Month -day $remoteServerTime.Day -hour $remoteServerTime.Hour -minute $remoteServerTime.Minute -second $remoteServerTime.Second);
    If ($remoteToSolarSkew)
    {
        $Skew = $remoteToSolarSkew.TotalSeconds - $ntpToSolarSkew;
        $stat=[math]::round($Skew,2);
        $symb=$stat.ToString().Substring(0,1);
        if ($symb -eq "-")
        {
            $tmp=$stat.ToString().Remove(0,1);
            Write-Host "Message: Clock drift: $stat.";
            Write-Host "Statistic: $tmp";
            exit 0;
        }
        else
        {
            $stat=[math]::round($Skew,2);
            Write-Host "Message: Clock drift: $stat s.";
            Write-Host "Statistic: $stat";
            exit 0;
        }
        #if ($stat 

    }
    Else
    {
        Write-Host "Message: Unable to Get-WmiObject Win32_UTCTime";
        exit 1;
    }
}
Else
{
    Write-Host "Message: Unable to query NTP server $ntpServer.";
    exit 1;
}  
 
