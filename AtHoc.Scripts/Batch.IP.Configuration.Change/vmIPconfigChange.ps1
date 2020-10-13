param(
 [Parameter(Mandatory=$True)]
  [string]$vmListCsvFile
)


function Set-Static {
 param(
  $Name,
  $Ipaddr,
  $subnetmask,
  $defaultGW,
  $dns1,
  $dns2
 )
 
 
    #Get NICS via WMI
    $NICs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $Name -Filter "IPEnabled=TRUE"
  
    foreach($NIC in $NICs) {
        $NetConnectionID = Get-WmiObject Win32_NetworkAdapter -ComputerName $Name | Where {$_.name -eq $NIC.Description} | select -expandProperty NetConnectionID 
        $cmd1 = "netsh int ip set dnsservers '$NetConnectionID' static $dns1 primary"
        $cmd2 = "netsh int ip add dnsservers '$NetConnectionID' $dns2"
        $cmd3 = "netsh int ip set address '$NetConnectionID' static $Ipaddr $subnetmask $defaultGW 1"

        Invoke-Command -ComputerName $Name -ScriptBlock{param($cmd) Invoke-Expression $cmd} -ArgumentList $cmd1 | Out-Null
        Invoke-Command -ComputerName $Name -ScriptBlock{param($cmd) Invoke-Expression $cmd} -ArgumentList $cmd2 | Out-Null
        Invoke-Command -ComputerName $Name -ScriptBlock{param($cmd) Invoke-Expression $cmd} -ArgumentList $cmd3 -sessionoption (new-pssessionoption -OperationTimeout 6000 ) -ErrorAction Continue -InDisconnectedSession | Out-Null
    }
}

function ResList ([string]$message) {

    $logEntry = (Get-Date -Format g) + ":`t" + $outline
    Write-Host $logEntry     
    Add-Content -Path $resfile -Value $logEntry 
}
 

$resfile = ".\results.txt"
$logfile = ".\log.txt"

Start-Transcript -Path $logfile

New-Item $resfile -ItemType file -Force

$vmList = Import-Csv $vmListCsvFile -UseCulture

#updating IP addresses
Write-Host "Updating IPs`n" -ForegroundColor Cyan

foreach ($vm in $vmList) {

    $currentIP = ""

    $currentIP = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $vm.name -Filter "IPEnabled=TRUE" -ErrorAction SilentlyContinue | select -Property ipaddress).ipaddress
    
    if ($currentIP.length -gt 0) {

        $outline = $vm.Name + "`t`t" + $currentIP + " --> " + $vm.ip

        ResList $outline      
        
    } else {

        $outline = $vm.Name + "`t`t" + "Can not connect"

        ResList -message $outline 
    }  

    Set-Static -Name $vm.Name -Dns1 $vm.dns1 -Dns2 $vm.dns2 -Ipaddr $vm.ip -subnetmask $vm.netmask -defaultGW $vm.gateway  
}


Stop-Transcript