; installateur MinouFlix pour Windows (Inno Setup) : un double-clic, raccourcis, désinstallation propre
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
[Setup]
AppId={{6B1D2C7A-4F0E-4C86-9D43-2A9F8E5B7C11}
AppName=MinouFlix
AppVersion={#AppVersion}
AppPublisher=MinouFlix
DefaultDirName={localappdata}\MinouFlix
DefaultGroupName=MinouFlix
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
DisableDirPage=yes
OutputDir=..\..\dist
OutputBaseFilename=MinouFlix-Setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\minouflix.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le bureau"; Flags: checkedonce

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Registry]
; liens minouflix:// (mot de passe oublié, connexion de la télé) : ouvrent l'appli
Root: HKCU; Subkey: "Software\Classes\minouflix"; ValueType: string; ValueData: "URL:MinouFlix"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\minouflix"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\minouflix\shell\open\command"; ValueType: string; ValueData: """{app}\minouflix.exe"" ""%1"""

[Icons]
Name: "{autoprograms}\MinouFlix"; Filename: "{app}\minouflix.exe"
Name: "{autodesktop}\MinouFlix"; Filename: "{app}\minouflix.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\minouflix.exe"; Description: "Lancer MinouFlix"; Flags: nowait postinstall skipifsilent
