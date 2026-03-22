# Wise System Monitor - Auto-start with Windows
# This script starts Wise System Monitor and minimizes the main window

$exePath = "C:\Program Files (x86)\Wise\Wise System Monitor\WiseSystemMonitor.exe"

# Check if already running
$process = Get-Process -Name "WiseSystemMonitor" -ErrorAction SilentlyContinue
if ($process) {
    # Already running, just minimize any main windows
    Start-Sleep -Seconds 2
} else {
    # Start the application
    Start-Process $exePath
    Start-Sleep -Seconds 3
}

# Minimize main window using Win32 API
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int SW_MINIMIZE = 6;
}
"@

Get-Process -Name "WiseSystemMonitor" -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.MainWindowHandle -ne [IntPtr]::Zero) {
        [Win32]::ShowWindow($_.MainWindowHandle, 6)
    }
}
