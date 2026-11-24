#define AppName "ClipForge Lite"
#define AppVersion "1.0.0"
#define BundleDir "..\dist_lite\ClipForgeLite"
[Setup]
AppId={{DABAAE1B-52B6-4A89-9CF6-1AAB3C0DCE11}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher="ClipForge"
AppPublisherURL="https://github.com/subayyalshah12/clipping-tool"
DefaultDirName={localappdata}\Programs\ClipForge Lite
DefaultGroupName=ClipForge Lite
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist_installer
OutputBaseFilename=ClipForge-Lite-Setup-v{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
SetupIconFile=ClipForge.ico
UninstallDisplayIcon={app}\ClipForge.ico
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: checkedonce
[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "Launch-Lite.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "ClipForge-Lite.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "ClipForge.ico"; DestDir: "{app}"; Flags: ignoreversion
[Icons]
Name: "{group}\ClipForge Lite"; Filename: "{app}\ClipForge-Lite.vbs"; WorkingDir: "{app}"; IconFilename: "{app}\ClipForge.ico"
Name: "{userdesktop}\ClipForge Lite"; Filename: "{app}\ClipForge-Lite.vbs"; WorkingDir: "{app}"; IconFilename: "{app}\ClipForge.ico"; Tasks: desktopicon
Name: "{group}\Uninstall ClipForge Lite"; Filename: "{uninstallexe}"
[Run]
Filename: "{app}\ClipForge-Lite.vbs"; Description: "Launch ClipForge Lite now"; Flags: postinstall nowait skipifsilent shellexec
[UninstallDelete]
Type: filesandordirs; Name: "{app}"
[Code]
function InitializeUninstall(): Boolean;
begin
  Result := MsgBox('Uninstalling also deletes downloaded videos, generated clips, settings and the local AI model. Continue?', mbConfirmation, MB_YESNO) = idYes;
end;
