' Wise System Monitor - Start with Floating Window Only
' This script starts Wise System Monitor and hides the main window
' while keeping the floating window visible

Set WshShell = CreateObject("WScript.Shell")
Set objShell = CreateObject("Shell.Application")

' Path to Wise System Monitor
strExe = "C:\Program Files (x86)\Wise\Wise System Monitor\WiseSystemMonitor.exe"

' Check if already running
Set colProcesses = GetObject("winmgmts:").ExecQuery("SELECT * FROM Win32_Process WHERE Name='WiseSystemMonitor.exe'")
If colProcesses.Count > 0 Then
    WScript.Echo "Wise System Monitor is already running."
    WScript.Quit 0
End If

' Start minimized using VBScript's Run method with window style 0 (hidden) or 2 (minimized)
' Using 2 (minimized) so the app starts but main window is minimized
WshShell.Run """" & strExe & """", 2, False

' Wait for application to start
WScript.Sleep 3000

' Send Alt+F4 to close the main window if it appears
' The floating window should remain
' This is a workaround since Wise doesn't have a built-in option
' WshShell.SendKeys "%{F4}"

WScript.Quit 0
