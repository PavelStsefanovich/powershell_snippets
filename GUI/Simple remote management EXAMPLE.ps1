<# This form was created using POSHGUI.com  a free online gui designer for PowerShell
.NAME
    Simple remote management EXAMPLE
.SYNOPSIS
    Example form with click events , reading and writing to GUI
#>

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = '494,276'
$Form.text                       = "Simple Management"
$Form.TopMost                    = $false

$compnameTxtbox                  = New-Object system.Windows.Forms.TextBox
$compnameTxtbox.multiline        = $false
$compnameTxtbox.width            = 307
$compnameTxtbox.height           = 20
$compnameTxtbox.location         = New-Object System.Drawing.Point(163,29)
$compnameTxtbox.Font             = 'Microsoft Sans Serif,10'

$Label1                          = New-Object system.Windows.Forms.Label
$Label1.text                     = "Computer name"
$Label1.AutoSize                 = $true
$Label1.width                    = 25
$Label1.height                   = 10
$Label1.location                 = New-Object System.Drawing.Point(29,29)
$Label1.Font                     = 'Microsoft Sans Serif,10'

$result                          = New-Object system.Windows.Forms.TextBox
$result.multiline                = $true
$result.width                    = 303
$result.height                   = 123
$result.location                 = New-Object System.Drawing.Point(166,67)
$result.Font                     = 'Microsoft Sans Serif,10'

$pingButton                      = New-Object system.Windows.Forms.Button
$pingButton.text                 = "Ping"
$pingButton.width                = 102
$pingButton.height               = 30
$pingButton.location             = New-Object System.Drawing.Point(27,67)
$pingButton.Font                 = 'Microsoft Sans Serif,10'

$closeButton                     = New-Object system.Windows.Forms.Button
$closeButton.text                = "Close"
$closeButton.width               = 102
$closeButton.height              = 30
$closeButton.location            = New-Object System.Drawing.Point(368,213)
$closeButton.Font                = 'Microsoft Sans Serif,10'

$restartButton                   = New-Object system.Windows.Forms.Button
$restartButton.text              = "Restart"
$restartButton.width             = 102
$restartButton.height            = 30
$restartButton.location          = New-Object System.Drawing.Point(29,114)
$restartButton.Font              = 'Microsoft Sans Serif,10'

$Form.controls.AddRange(@($compnameTxtbox,$Label1,$result,$pingButton,$closeButton,$restartButton))

$pingButton.Add_Click({ ping })
$restartButton.Add_Click({ restart })
$closeButton.Add_Click({ closeForm })



function ping(){ 
    $result.text += "`r`n" + "Pinging " + $compnameTxtbox.text
    if(test-connection $compnameTxtbox.text){
        $result.text += "`r`nConnection successfull"
    }else{
         $result.text += "`r`nConnection Failed"
    }
    }

function restart(){
     $result.text += "`r`n" +  "Restarting " + $compnameTxtbox.text
    Restart-Computer -ComputerName $compnameTxtbox.text -Force
     $result.text += "`r`n" + $compnameTxtbox.text + " restarted"
}

function closeForm(){$Form.close()}
    


[void]$Form.ShowDialog()