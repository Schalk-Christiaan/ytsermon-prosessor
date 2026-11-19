; @stelsel setup-iss
;   soort: bevel
;   wanneer: deur .github/workflows/windows.yml (ISCC)
;   groep: installer | Installeerder
;   skryf: installer/Output/Setup.exe
;   doel: per-gebruiker-installeerder sonder admin in %LOCALAPPDATA%\Preekverwerker (yt-dlp -U kan skryf); installeer Ollama stil as dit nog nie daar is nie
;   status: oop

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6B0E3C1A-2F4D-4E7B-9C1E-5A8F0D2B7E61}
AppName=Preekverwerker
AppVersion={#AppVersion}
AppPublisher=Gereformeerde Kerk Oranjerivier
DefaultDirName={localappdata}\Preekverwerker
DefaultGroupName=Preekverwerker
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=Output
OutputBaseFilename=Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\preekverwerker.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "nl"; MessagesFile: "compiler:Languages\Dutch.isl"

[Tasks]
Name: "desktopicon"; Description: "Ikoon op die lessenaar"; Flags: checkedonce

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\deps\yt-dlp.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\deps\ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\deps\ffprobe.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\deps\OllamaSetup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: NeedsOllama

[Icons]
Name: "{group}\Preekverwerker"; Filename: "{app}\preekverwerker.exe"
Name: "{userdesktop}\Preekverwerker"; Filename: "{app}\preekverwerker.exe"; Tasks: desktopicon

[Run]
Filename: "{tmp}\OllamaSetup.exe"; Parameters: "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART"; StatusMsg: "Installeer Ollama (die KI)…"; Check: NeedsOllama; Flags: waituntilterminated
Filename: "{app}\preekverwerker.exe"; Description: "Maak Preekverwerker oop"; Flags: nowait postinstall skipifsilent

[Code]
function NeedsOllama: Boolean;
begin
  Result := not FileExists(ExpandConstant('{localappdata}\Programs\Ollama\ollama.exe'));
end;
