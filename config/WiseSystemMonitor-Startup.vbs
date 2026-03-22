' Wise System Monitor - Auto-start with Windows (VBScript wrapper)
' Place shortcut to this file in: shell:startup

Set WshShell = CreateObject("WScript.Shell")
Set objShell = CreateObject("Shell.Application")

' Path to PowerShell script
strScript = "C:\Users\filip\dev\openclaw-setup\config\WiseSystemMonitor-Startup.ps1"

' Run PowerShell script hidden
strCommand = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strScript & """"

' Run hidden (window style 0)
WshShell.Run strCommand, 0, False

' Alternative: Start Wise directly minimized if PowerShell script fails
strExe = "C:\Program Files (x86)\Wise\Wise System Monitor\WiseSystemMonitor.exe"
' WshShell.Run """" & strExe & """", 2, False  ' 2 = minimized
