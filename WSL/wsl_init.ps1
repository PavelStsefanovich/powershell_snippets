param (
    $distro_download_url,
    $distro_name
)

$ErrorActionPreference = 'stop'
$s_name = $MyInvocation.MyCommand.Name
write ":: ($s_name):"

$wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

if (!$wsl)
{
    write ' enabling WSL feature'
    $wsl = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
}

if ($wsl.RestartNeeded) {
    Write-Warning "restart required before WSL can be enabled"
    write " re-run this script after restart to continue"
    exit
}
else {
    write " WSL feature enabled"
}

if ($distro_download_url)
{
    if (!$distro_name)
    {
        $distro_name = Split-Path $distro_download_url -Leaf
    }

    $zipfilename = "$distro_name`.zip"
    $do_download = $true

    if (gi $zipfilename -ErrorAction SilentlyContinue)
    {
        Write-Warning " distro package '$zipfilename' found locally"
        $reply = ''

        while ($reply -notin ('o','l','s'))
        {
            
            write " (o)verwrite?  use_(l)ocal?  (s)kip?"
            $reply = [string]$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character

            switch ($reply) {
                'l' { $do_download = $false }
                's' { exit }
                Default { Write-Warning " unknown option '$reply'" }
            }
        }
    }

    if ($do_download)
    {
        write " downloading distro from '$distro_download_url'"
        Invoke-WebRequest -Uri $distro_download_url -OutFile $zipfilename -UseBasicParsing
    }

    write " unpacking distro '$zipfilename'"
    Expand-Archive $zipfilename -Force

    write " initializing distro '$distro_name'"
    $distro_exe = (ls $distro_name/*.exe).FullName
    start $distro_exe -WorkingDirectory (Split-Path $distro_exe)
}

write " to get WSL manual, type 'wsl --help'"

write "($s_name): SUCESS"
