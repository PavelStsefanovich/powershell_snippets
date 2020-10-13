
$ErrorActionPreference = 'Stop'

$configUpdate = @(
    @{'name'='EasyConnect.Integration';'publicKeyToken'='283e29b0f5ab60e5';'culture'='neutral';'oldVersion'='0.0.0.0-5.3.0.3';'newVersion'='5.4.0.0'},
    @{'name'='EasyConnect.Common';'publicKeyToken'='283e29b0f5ab60e5';'culture'='neutral';'oldVersion'='0.0.0.0-5.3.0.18';'newVersion'='5.4.0.1'}
)

#- reading IWS installation directory from the registry

try {
    Write-Host " - looking for IWS installation directory in the registry ..." -ForegroundColor DarkGray
    $iwsInstallDir = (gp HKLM:\SOFTWARE\Wow6432Node\AtHocServer\Install).AppLoc
} catch {
    Write-Warning "Failed to read IWS installation directory from the registry with exception:"
    throw $_
}

$webconfigFiles = `
    (Join-Path $iwsInstallDir "wwwroot\client\web.config"),`
    (Join-Path $iwsInstallDir "wwwroot\SelfService\web.config") |
    get-item

#- backing up web.config files

$backupDirectory = Join-Path $PSScriptRoot 'customscript_bkp_webconfig'
while (Test-Path $backupDirectory) {
    Write-Warning "Backup directory already exists: '$backupDirectory'. To proceed, please remove it and press any key to continue ..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
}
mkdir $backupDirectory -Force | Out-Null

$webconfigFiles | %{
    $parentDir = Join-Path $backupDirectory (Split-Path (Split-Path $_ -Parent) -Leaf)
    mkdir $parentDir -Force | Out-Null
    write-host " - backing up file: '$($_.FullName) ...'" -ForegroundColor DarkGray
    cp $_.FullName -Destination $parentDir}

#- updating web.config files

foreach ($file in $webconfigFiles) {

    Write-Host " - updating: '$($file.FullName)' ..." -ForegroundColor DarkGray
    $xml = [xml](cat $file.FullName)
    $runtime = $xml.configuration.runtime
    $isUpdateConfigPresent = $false 
    
    if (!$runtime) {
        $runtime = $xml.CreateNode("element","runtime","")
        $xml.configuration.AppendChild($runtime)

    } else {
        foreach ($name in $runtime.GetElementsByTagName('assemblyBinding').dependentAssembly.assemblyIdentity.name) {
            if ($name -in $configUpdate.name) {
                $isUpdateConfigPresent = $true
            }
        }
    }

    if ($isUpdateConfigPresent) {
        Write-Warning "File appears to be already updated (skipping): '$($file.fullname)'"
    
    } else {
        
        $assemblyBinding = $xml.CreateNode("element","assemblyBinding","urn:schemas-microsoft-com:asm.v1")

        foreach ($assemblyConfig in $configUpdate) {
            
            $assemblyIdentity = $xml.CreateNode("element","assemblyIdentity","")
            $assemblyIdentity.SetAttribute('name',$assemblyConfig.name)
            $assemblyIdentity.SetAttribute('publicKeyToken',$assemblyConfig.publicKeyToken)
            $assemblyIdentity.SetAttribute('culture',$assemblyConfig.culture)
            
            $bindingRedirect = $xml.CreateNode("element","bindingRedirect","")
            $bindingRedirect.SetAttribute('name',$assemblyConfig.name)
            $bindingRedirect.SetAttribute('publicKeyToken',$assemblyConfig.publicKeyToken)
            $bindingRedirect.SetAttribute('culture',$assemblyConfig.culture)

            $dependentAssembly = $xml.CreateNode("element","dependentAssembly","")
            
            $dependentAssembly.AppendChild($assemblyIdentity) | Out-Null
            $dependentAssembly.AppendChild($bindingRedirect) | Out-Null
            $assemblyBinding.AppendChild($dependentAssembly) | Out-Null
            $runtime.AppendChild($assemblyBinding) | Out-Null
        }
    }

    try {
        $xml.Save($file.FullName)
    } catch {
        Write-Warning "Failed to save updated file: '$($file.FullName)' with exception:"
        throw $_
    }
}