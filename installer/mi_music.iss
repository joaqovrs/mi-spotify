; Instalador de Mi Music para Windows, con Inno Setup.
;
; Empaqueta lo que deja `flutter build windows --release` en
; app/build/windows/x64/runner/Release/ (el .exe y sus .dll) en un instalador
; clasico de Windows. No pide permisos de administrador (PrivilegesRequired
; = lowest): se instala en la carpeta del usuario, como Discord o VS Code,
; sin el cuadro de UAC.
;
; Se compila con generar-instalador.ps1, que primero corre el build de
; Flutter y despues llama a ISCC.exe sobre este archivo.

#define MyAppName "Mi Music"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Joaquin Varas"
#define MyAppExeName "mi_spotify.exe"
#define ReleaseDir "..\app\build\windows\x64\runner\Release"

[Setup]
; Fijo y unico para esta app: Inno Setup lo usa para identificar
; actualizaciones futuras (mismo AppId = actualiza en vez de duplicar).
AppId={{EDEF4D66-F7D6-4928-810D-A34EC5B9E4CB}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=MiMusicSetup
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Sin admin: se instala para el usuario actual nada mas, como Discord o
; VS Code. Evita el cuadro de UAC, que no tiene sentido para una app privada
; de un solo usuario.
PrivilegesRequired=lowest

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Abrir Mi Music"; Flags: nowait postinstall skipifsilent
