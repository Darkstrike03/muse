; Inno Setup script for the Muse Windows installer.
;
; Built by .github/workflows/release.yml:
;   iscc tool\installer.iss /DAppVersion=1.2.3
; Expects the Flutter release build at
;   build\windows\x64\runner\Release\
; and the Tor expert bundle installed at tor\ (tool\setup_tor.ps1).

#define AppName "Muse"
#ifndef AppVersion
#define AppVersion "0.0.0"
#endif

[Setup]
AppId={{7E1F6C42-9A5B-4E8D-BC31-2F4D6A0E5C77}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Darkstrike03
AppPublisherURL=https://github.com/Darkstrike03/muse
DefaultDirName={autopf}\Muse
DefaultGroupName=Muse
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=muse-setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\muse.exe

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; Flags: recursesubdirs ignoreversion
Source: "..\tor\*"; DestDir: "{app}\tor"; \
    Flags: recursesubdirs ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\NOTICE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\THIRD-PARTY-LICENSES.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\muse.exe"
Name: "{group}\Uninstall {#AppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\muse.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\muse.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; \
    Flags: nowait postinstall skipifsilent
