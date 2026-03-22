# Wise System Monitor - Start with Floating Window Only
# Starts Wise System Monitor and minimizes/hides the main window

$exePath = "C:\Program Files (x86)\Wise\Wise System Monitor\WiseSystemMonitor.exe"

# Check if already running
$process = Get-Process -Name "WiseSystemMonitor" -ErrorAction SilentlyContinue
if ($process) {
    Write-Host "Wise System Monitor is already running."
    # Bring floating window to front if main window exists
    exit 0
}

# Start the application
Start-Process $exePath

# Wait for it to start
Start-Sleep -Seconds 3

# Find the main window and minimize it
# The floating window has a different title pattern
$mainWindow = Get-Process -Name "WiseSystemMonitor" | ForEach-Object {
    $_.MainWindowHandle
} | Where-Object { $_ -ne [IntPtr]::Zero }

if ($mainWindow) {
    # Minimize the main window using Win32 API
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int SW_MINIMIZE = 6;
    public const int SW_HIDE = 0;
}
"@
    
    # Minimize all Wise System Monitor windows
    Get-Process -Name "WiseSystemMonitor" | ForEach-Object {
        if ($_.MainWindowHandle -ne [IntPtr]::Zero) {
            [Win32]::ShowWindow($_.MainWindowHandle, 6)  # SW_MINIMIZE
        }
    }
    
    Write-Host "Wise System Monitor started and main window minimized."
} else {
    Write-Host "Wise System Monitor started (floating window only mode)."
}
