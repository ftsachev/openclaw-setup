# Minimize Wise System Monitor Main Window (keep floating window)
# Uses Win32 API to minimize the main window while keeping the floating widget visible

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    public const int SW_MINIMIZE = 6;
    public const int SW_HIDE = 0;
    public const int SW_SHOWMINIMIZED = 2;
}
"@

# Find Wise System Monitor process
$process = Get-Process -Name "WiseSystemMonitor" -ErrorAction SilentlyContinue

if (-not $process) {
    Write-Host "Wise System Monitor is not running."
    exit 0
}

# Get all windows for this process and minimize the main one
$minimized = 0
foreach ($proc in $process) {
    if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
        $title = $proc.MainWindowTitle
        Write-Host "Found window: $title (PID: $($proc.Id))"
        
        # Minimize windows that contain "Wise" or "System" or "Monitor" in title
        # The floating widget typically has no title or a simple one
        if ($title -match "Wise|System|Monitor|Process|CPU|Memory") {
            [Win32]::ShowWindow($proc.MainWindowHandle, 6)  # SW_MINIMIZE
            Write-Host "  -> Minimized: $title"
            $minimized++
        }
    }
}

if ($minimized -eq 0) {
    Write-Host "No main windows found - only floating window is visible."
} else {
    Write-Host "Minimized $minimized window(s). Floating window should remain visible."
}
