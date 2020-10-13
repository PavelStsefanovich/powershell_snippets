param(
 [Parameter(Mandatory=$True)]
  [string]$vmlistCsvfile,
  
 [Parameter(Mandatory=$True)]
  [string]$certificateFile,

 [Parameter(Mandatory=$True)]
  [string]$certDomain,

 [Parameter(Mandatory=$True)]
  [string]$certPassw

)


function Write-Log ($message) {
    Write-Output $message | Out-File $script:logfile -Append -Encoding ascii
}


#=== Begin ===

Get-PSSession | Remove-PSSession

$scritpDir = $PWD.Path
$logfile = ($MyInvocation.MyCommand.Name + ".log")
$outfilepath = ("iis.ssl.update_" + (Get-Date  -Format yyyy.MM.dd) + ".csv")
$tempdir = "Stuff"
#(ps)
$ps_tempfile = "temp.txt"
" " > $ps_tempfile

if (Test-Path $logfile) {rm $logfile -Force -ErrorAction Stop}
if (!(Test-Path $certificateFile)) {throw "Can't find $certificateFile in directory: $scritpDir"}
$computerNames = (Import-Csv $vmlistCsvfile -ErrorAction stop).name | ?{$_.length -gt 2}  | %{$_.split('.')[0]}
if ($computerNames.length -eq 0) {throw "Can't find column 'Name' in file: $vmlistCsvfile"}
$domain = (Get-WmiObject Win32_ComputerSystem).Domain

$SERVERS = @()

#--- Print parameters

Write-Output "_______________________________________________"
Write-Output " Parameters:`n"
Write-Output "  vmlistCsvfile:`t$vmlistCsvfile"
Write-Output "  certificateFile:`t$certificateFile"
Write-Output "  domainName:`t`t$domain"
Write-Output "_______________________________________________"

#--- Creating connection to remote machines
Write-Output "`n >>> Establishing connection...`n"

foreach ($computer in $computerNames) {
    
    $Server = New-Object PSObject
    $Server | Add-Member -MemberType NoteProperty -Name "Name" -Value $computer
    $Server | Add-Member -MemberType NoteProperty -Name "Domain" -Value $domain
    $Server | Add-Member -MemberType NoteProperty -Name "IP" -Value ""
    $Server | Add-Member -MemberType NoteProperty -Name "Accessible" -Value $false
    $Server | Add-Member -MemberType NoteProperty -Name "IISinstalled" -Value $false
    $Server | Add-Member -MemberType NoteProperty -Name "BindingDomain" -Value ""
    #$Server | Add-Member -MemberType NoteProperty -Name "SSLuptodate" -Value $false
    $Server | Add-Member -MemberType NoteProperty -Name "Result" -Value "failed"
    $Server | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value ""

    $result = $true     
    
    try {
        $ip =  (Test-Connection ($computer + ".$domain") -Count 1 -ErrorAction stop).IPV4Address.IPAddressToString
        $Server.IP = $ip

        $session = New-PSSession -ComputerName $computer -ErrorAction Stop
        $Server.Accessible = $True

        $Server.IISinstalled = Invoke-Command -Session $session -ScriptBlock {

            if ('WebAdministration' -in (Get-Module -ListAvailable).name) {
                return $true
            } else {
                return $false
            }
        }
    }
    catch {
        $result = $false
        $errorMessage = $_.exception.message.tostring()
        Write-Warning "(!)        $computer`: $errorMessage"
        Write-Log "$computer (!err): $errorMessage"
        $Server.ErrorMessage = $errorMessage   
    }

    if ($result) {
        if (!$Server.IISinstalled) {
            $errorMessage = "IIS not installed"
            Write-Warning "(!)        $computer`: $errorMessage"
            Write-Log "$computer (!err): $errorMessage"
            $Server.ErrorMessage = $errorMessage
        } else {
            $session
        }
    }
    
    $SERVERS += [PSCustomObject]$Server
}

#--- Installing certificates on remote machines
Write-Output "`n >>> Installing certificates...`n"

foreach ($Server in $SERVERS) {
    
    if ($Server.Accessible -and $Server.IISinstalled) {
        
        Write-Output (" " + $Server.Name)
        $result = $True

        try {
            $remoteTempDir = "\\" + $Server.name + "\C$\$tempdir\"
            $localTempDir = "C:\$tempdir"
            if (!(Test-Path $remoteTempDir)) {mkdir $remoteTempDir -Force -ErrorAction Stop | Out-Null}
            cp -Path $certificateFile -Destination $remoteTempDir -Force -ErrorAction stop
        
            $session = Get-PSSession | ?{$_.ComputerName -eq $Server.Name}

            #checking existing binding domain
            $Server.BindingDomain = Invoke-Command -Session $session -ErrorAction stop -ScriptBlock {

                Import-Module WebAdministration

                $bindingThumbprint = (Get-item IIS:\SslBindings\*!443).Thumbprint
                $bindingDomain = [regex]::Match((Get-ChildItem Cert:\LocalMachine\My |
                ?{$_.Thumbprint -eq $bindingThumbprint}).Subject,'(?<=CN\=\*\.).*?(?=\,\s)').value
                return $bindingDomain
            }

            if ($Server.BindingDomain -eq $certDomain) {

                #replacing certificate
                Invoke-Command -Session $session -ArgumentList $localTempDir,$certificateFile,$certPassw,$certDomain -ErrorAction stop -ScriptBlock {
                    
                    $certPath = $args[0] + "\" + $args[1].trimstart('.\/')
                    $certDomain = $args[3]

                    Get-ChildItem Cert:\LocalMachine\My | ?{$_.Subject -like "CN=`*.$certDomain*"} | Remove-Item
                    
                    certutil -p $args[2] -importpfx $certPath | Out-Null
                    
                    $thumbPrint = Get-ChildItem Cert:\LocalMachine\My |
                    ?{$_.subject -like "CN=`*.$certDomain*"} |
                    Select-Object -ExpandProperty Thumbprint
                  
                    Get-Item IIS:\SslBindings\*!443 | Remove-Item

                    Get-Item "Cert:\LocalMachine\My\$thumbPrint" | New-Item -Path IIS:\SslBindings\*!443 | Out-Null
                }                
            } else {
                $result = $false
                if ($Server.BindingDomain.length -gt 0) {
                    $errorMessage = ("Current certificate belonges to another domain ('" + $Server.BindingDomain + "')")
                } else {
                    $errorMessage = ("No binding found")
                }
                Write-Warning "(!)        $computer`: $errorMessage"
                Write-Log "$computer (!err): $errorMessage"
                $Server.ErrorMessage = $errorMessage
            }
        }
        catch {
            $result = $false
            $errorMessage = $_.exception.message.tostring()
            Write-Warning "(!)        $computer`: $errorMessage"
            Write-Log "$computer (!err): $errorMessage"
            $Server.ErrorMessage = $errorMessage 
        }
        
        if ($result) {
            $Server.Result = "Ok"
            Write-Output "  ok"
            Write-Log "$computer : Ok"
        }
    }  
}

#--- Displaying and exporting results
if (Test-Path $outfilepath) {rm $outfilepath -Force}
Write-Output ""
Write-Output "_______________________________________________"
Write-Output " RESULTS:"
$SERVERS | sort Result,Name -Descending | %{$_ | select Result,Name,Errormessage | Format-Table -AutoSize}

$SERVERS | %{$_ | Export-Csv $outfilepath -NoTypeInformation -Append}
