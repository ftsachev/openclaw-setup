' Create-WiseStartupShortcut.ps1
# Creates a shortcut in Windows Startup folder for Wise System Monitor

$WshShell = New-Object -ComObject WScript.Shell
$startupPath = $WshShell.SpecialFolders("Startup")
$shortcutPath = Join-Path $startupPath "Wise System Monitor - Float Only.lnk"

# Path to VBScript
$vbsPath = "C:\Users\filip\dev\openclaw-setup\config\WiseSystemMonitor-Startup.vbs"

# Create shortcut
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "wscript.exe"
$shortcut.Arguments = "`"$vbsPath`""
$shortcut.WorkingDirectory = Split-Path $vbsPath
$shortcut.IconLocation = "shell32.dll,13"
$shortcut.Description = "Start Wise System Monitor with floating window only"
$shortcut.Save()

Write-Host "Shortcut created: $shortcutPath"
Write-Host ""
Write-Host "Wise System Monitor will now start automatically at Windows login."
Write-Host "The main window will be minimized, keeping only the floating widget visible."
