$WinMetricsKey = 'HKCU:\Control Panel\Desktop\WindowMetrics\'
Set-ItemProperty $WinMetricsKey -Name CaptionHeight -Value -285
Set-ItemProperty $WinMetricsKey -Name CaptionWidth -Value -285
Set-ItemProperty $WinMetricsKey -Name ScrollHeight -Value -150
Set-ItemProperty $WinMetricsKey -Name ScrollWidth -Value -150
Set-ItemProperty $WinMetricsKey -Name PaddedBorderWidth -Value 0