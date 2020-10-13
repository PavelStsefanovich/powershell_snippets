function Get-OkCancel
{
[CmdletBinding()] param ($question=
"Is the answer to Life the Universe and Everything 42?")
function New-Point ($x,$y)
{New-Object System.Drawing.Point $x,$y}
Add-Type -AssemblyName System.Drawing,System.Windows.Forms
$form = New-Object Windows.Forms.Form
$form.Text = "Pick OK or Cancel"
$form.Size = New-Point 400 200
$label = New-Object Windows.Forms.Label
$label.Text = $question
$label.Location = New-Point 50 50
$label.Size = New-Point 350 50
$label.Anchor="top"
$ok = New-Object Windows.Forms.Button
$ok.text="OK"
$ok.Location = New-Point 50 120
$ok.Anchor="bottom,left"
$ok.add_click({
$form.DialogResult = "OK"
$form.close()
})

$cancel = New-Object Windows.Forms.Button
$cancel.text="Cancel"
$cancel.Location = New-Point 275 120
$cancel.Anchor="bottom,right"
$cancel.add_click({
$form.DialogResult = "Cancel"
$form.close()
})
$form.controls.addRange(($label,$ok,$cancel))
$form.Add_Shown({$form.Activate()})
$form.ShowDialog()
}

Get-OkCancel