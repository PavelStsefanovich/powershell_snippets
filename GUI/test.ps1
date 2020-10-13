$sig = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
Add-Type -MemberDefinition $sig -name NativeMethods -namespace Win32
$hwnd = @(Get-Process outlook)[0].MainWindowHandle
$hwnd
# Minimize window
[Win32.NativeMethods]::ShowWindowAsync($hwnd, 2)
# Restore window
[Win32.NativeMethods]::ShowWindowAsync($hwnd, 4)
