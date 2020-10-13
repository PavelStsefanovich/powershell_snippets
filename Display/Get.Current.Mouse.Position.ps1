Add-Type -AssemblyName System.Windows.Forms

1..1000 | %{
  $X = [System.Windows.Forms.Cursor]::Position.X
  $Y = [System.Windows.Forms.Cursor]::Position.Y
  Write-Output "X: $X | Y: $Y"
  Sleep 1
}
