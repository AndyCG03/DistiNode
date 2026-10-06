; Instalador de DistiNode para Windows (Inno Setup 6).
; Lo genera tool/build_windows.ps1, que antes compila la app y copia el runtime de Visual C++.
;   iscc /DAppVersion=1.0.0 installer\windows\distinode.iss

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#define AppName "DistiNode"
#define AppExe "distinode.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{6B3C2D8E-4E2A-4C7B-9C6E-2F1D7A9B5E31}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=DistiNode · CUJAE
AppComments=Diseña sistemas distribuidos y míralos funcionar. Versión de escritorio, sin cuentas.
AppSupportURL=https://github.com/AndyCG03/web-sistemas-distribuidos
AppUpdatesURL=https://github.com/AndyCG03/web-sistemas-distribuidos/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Se puede instalar sin permisos de administrador (solo para el usuario actual).
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\..\build\installer
OutputBaseFilename=DistiNode-{#AppVersion}-windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
WizardStyle=modern
Compression=lzma2/ultra64
SolidCompression=yes
CloseApplications=yes
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoDescription=Instalador de {#AppName}

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; Comment: "Diseña sistemas distribuidos y míralos funcionar"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; Los proyectos (Documentos\DistiNode\Proyectos) son del usuario: el desinstalador no los borra.
