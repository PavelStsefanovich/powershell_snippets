param (
    [string]$serverlistFilePath = ".\serverlist.json"
)

try {
    $serverList = (ConvertFrom-Json (cat (Resolve-Path $serverlistFilePath -ErrorAction Stop).Path -Raw) -ErrorAction Stop).Servers
} catch {
    throw "!!ERROR: Serverlist file not found at path: $serverlistFilePath"
}

foreach ($server in $serverList) {
    Write-Host "  UPDATING: $server"

    Invoke-Command -ComputerName $server -FilePath .\Jenkins.Slave.Update.Java.Path.ps1 -ErrorAction Continue
}