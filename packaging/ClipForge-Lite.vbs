Set fso=CreateObject("Scripting.FileSystemObject")
Set sh=CreateObject("WScript.Shell")
d=fso.GetParentFolderName(WScript.ScriptFullName)
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & d & "\Launch-Lite.ps1""",0,False
