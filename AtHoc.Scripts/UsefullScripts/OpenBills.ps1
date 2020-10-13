 param (
    [string]$billsRootDir,
    [string]$year,
    [string]$month,
    [switch]$all,
    [switch]$help
 )

 function Display-Help {
    Write-Host "`n__________________________"
    Write-Host "Params:" -ForegroundColor Cyan
    Write-Host "`tbillsRootDir" -ForegroundColor DarkCyan -NoNewline
    Write-Host "`t- root directory of bills for all utilities (Default: `$currentDir\..\Documents\Bills)"
    Write-Host "`tyear" -ForegroundColor DarkCyan -NoNewline
    Write-Host "`t`t- only looks for bills from this year"
    Write-Host "`tmonth" -ForegroundColor DarkCyan -NoNewline
    Write-Host "`t`t- only looks for bills from this month"
    Write-Host "`tall" -ForegroundColor DarkCyan -NoNewline
    Write-Host "`t`t- use to open bills from beginning of times"
    Write-Host "`nDefault:" -ForegroundColor Cyan -NoNewline
    Write-Host " opens bills for current month of current year"
    Write-Host "=========================="
 }

 function Use-RunAs { #elevates script permissions to admininistrator
    
    # Check if script is running as Adminstrator and if not use RunAs 
    # Use Check Switch to check if admin 
     
    param([Switch]$Check) 
     
    $IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent() 
        ).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
         
    if ($Check) { return $IsAdmin }     
 
    if ($MyInvocation.ScriptName -ne "") 
    {  
        if (-not $IsAdmin)  
        {  
            try 
            {  
                $arg = "-file `"$($MyInvocation.ScriptName)`"" 
                Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $arg -ErrorAction 'stop'  
            } 
            catch 
            { 
                Write-Warning "Error - Failed to restart script with runas"  
                break               
            } 
            exit # Quit this session of powershell 
        }
		else
		{
			write-output "Running as administrator...OK"
		}
    }  
    else  
    {  
        Write-Warning "Error - Script must be saved as a .ps1 file first"  
        break  
    }  
} 

 function Get-ScriptDirectory { #returns directory from where this script runs
 
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value;
    if($Invocation.PSScriptRoot)
    {
        $Invocation.PSScriptRoot;
    }
    Elseif($Invocation.MyCommand.Path)
    {
        Split-Path $Invocation.MyCommand.Path
    }
    else
    {
        $Invocation.InvocationName.Substring(0,$Invocation.InvocationName.LastIndexOf("\"));
    }
 }

 function Wait-Anykey([string]$message) { #displays message (optional) and awaits any key stroke

    if ($message)
    {
        Write-Output "`n$message"
    }
    
    Write-Host "Press any key..."
    $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

 function Open-Bill ([string]$path) {
    Invoke-Item $path  
 }

 function Nothing-Found ([string]$bill) {
    Write-host "No receipts for $bill for "$invoiceYear"_"$invoiceMonth -ForegroundColor Yellow
 }

# === Start === #

if ($help) {
    Display-Help
    Wait-Anykey
    exit
}

# Use-RunAs 
 $currentDir = Get-ScriptDirectory
 $currentDate = (Get-Date -Format MM.yyyy).Split(".")
 $curMonth = $currentDate[0]
 $curYear = $currentDate[1]

 if (!$billsRootDir) {
    
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Root) {
        $path = $drive + "GoogleDrive_Business\Documents\Finances\Bills"
        if (Test-Path $path) {
            $billsRootDir = $path
            break
        }
    }

    if (!$billsRootDir) {
        throw "Could not locate <BillsRootDir> and it's not specified as paramter."
    } else {
        Write-Host "billsRootDir: $billsRootDir"
    }
 }

 #sets target year (default: current year)
 if ($year) {
    $invoiceYear = $year
 } else {
    $invoiceYear = $curYear
 }
 
 if ($month) {
    $invoiceMonth = $month
 } else {
    $invoiceMonth = $curMonth
 }

 #gets list of bills
 $bills = Get-ChildItem $billsRootDir | ?{$_.PSIsContainer}
 
[boolean]$receiptAwhs = $false
[boolean]$receiptCmcst = $false
[boolean]$receiptRent = $false
[boolean]$receiptTMbl = $false
 
 #gets receipts for each bill 
 foreach ($dir in $bills) {
   
    #gets all receipt for a year
    $receipts = Get-ChildItem (Convert-Path $dir.PSpath) | ?{!$_.PSIsContainer} | ?{$_.Name -match $invoiceYear.ToString()} | ?{$_.Name -like '*.pdf' -or $_.Name -like '*.jpg'}

    #selects only specific month receipt
    foreach ($receipt in $receipts) {
        if (!$all) {
            if ($receipt.Name.contains("$invoiceMonth")) {
                Open-Bill (Convert-Path ($receipt.pspath))
                if ($dir.Name -like '*ApplianceWarehouse') {
                $receiptAwhs = $true
                }
                if ($dir.Name -like '*Comcast') {
                $receiptCmcst = $true
                }
                if ($dir.Name -like '*Rent') {
                $receiptRent = $true
                }
                if ($dir.Name -like '*T-Mobile') {
                $receiptTMbl = $true
                }
                break
            }
        } else {
            Open-Bill (Convert-Path ($receipt.pspath))
            if ($dir.Name -like '*ApplianceWarehouse') {
            $receiptAwhs = $true
            }
            if ($dir.Name -like '*Comcast') {
            $receiptCmcst = $true
            }
            if ($dir.Name -like '*Rent') {
            $receiptRent = $true
            }
            if ($dir.Name -like '*T-Mobile') {
            $receiptTMbl = $true
            }
        }    
    }
 }

 if (!$receiptAwhs -or !$receiptCmcst -or !$receiptRent -or !$receiptTMbl) {
 
		 if (!$receiptAwhs) {
			Nothing-Found "AppliancesWarehouse"
		 }

		 if (!$receiptCmcst) {
			Nothing-Found "Comcast"
		 }

		 if (!$receiptRent) {
			Nothing-Found "Rent"
		 }

		 if (!$receiptTMbl) {
			Nothing-Found "T-Mobile"
		 }
		 
		  Wait-Anykey  
 }
 
# === End === #>