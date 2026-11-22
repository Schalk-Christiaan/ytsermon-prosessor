; @stelsel setup-iss
;   soort: bevel
;   wanneer: deur .github/workflows/windows.yml (ISCC)
;   groep: installer | Installeerder
;   skryf: installer/Output/Setup.exe
;   doel: per-gebruiker-installeerder sonder admin in %LOCALAPPDATA%\Preekverwerker met yt-dlp/ffmpeg/ffprobe en die VC++-looptyd langs die exe; laai Ollama af en installeer dit stil as dit ontbreek; opgradeer oor 'n lopende app; deïnstalleer behou die werkgids tensy die gebruiker ja sê
;   status: bou
; Plan: planne/windows-installeerder.md. Saved as UTF-8 with BOM so ISCC reads the Afrikaans correctly.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
; OllamaSetup is 1.86 GB, too big to embed: downloaded at install time and checked against this hash.
#define OllamaVersion "v0.40.16"
#define OllamaSha256 "84db4f756ddc9e091142a85cdc0f7ae5db68bc9b3e075f114388b326f8ed912d"
; Where path_provider's getApplicationSupportDirectory() puts the work folder and settings.
#define DataDir "{userappdata}\za.co.gkoranjerivier\preekverwerker"

[Setup]
AppId={{6B0E3C1A-2F4D-4E7B-9C1E-5A8F0D2B7E61}
AppName=Preekverwerker
AppVersion={#AppVersion}
VersionInfoVersion={#AppVersion}
AppPublisher=Gereformeerde Kerk Oranjerivier
DefaultDirName={localappdata}\Preekverwerker
DefaultGroupName=Preekverwerker
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
MinVersion=10.0.17763
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no
OutputDir=Output
OutputBaseFilename=Setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\preekverwerker.exe
UninstallDisplayName=Preekverwerker
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "nl"; MessagesFile: "compiler:Languages\Dutch.isl"

; Inno has no Afrikaans; the visible Dutch strings are overridden here.
[Messages]
ButtonBack=< &Terug
ButtonNext=&Volgende >
ButtonInstall=&Installeer
ButtonCancel=Kanselleer
ButtonFinish=&Klaar
ButtonYes=&Ja
ButtonNo=&Nee
WizardSelectTasks=Kies ekstra take
SelectTasksDesc=Wat moet nog gedoen word?
SelectTasksLabel2=Kies wat Setup ook moet doen terwyl dit [name] installeer, en klik dan Volgende.
WizardReady=Gereed om te installeer
ReadyLabel1=Setup is gereed om [name] op jou rekenaar te installeer.
ReadyLabel2a=Klik Installeer om voort te gaan, of Terug om iets te verander.
WizardInstalling=Besig om te installeer
InstallingLabel=Wag asseblief terwyl Setup [name] op jou rekenaar installeer.
WizardPreparing=Berei voor
PreparingDesc=Setup maak gereed om [name] te installeer.
FinishedHeadingLabel=[name] is geïnstalleer
FinishedLabelNoIcons=[name] is op jou rekenaar geïnstalleer.
FinishedLabel=[name] is op jou rekenaar geïnstalleer. Jy kan dit oopmaak met die ikoon in die Start-kieslys.
ClickFinish=Klik Klaar om Setup toe te maak.
ExitSetupTitle=Stop Setup
ExitSetupMessage=Setup is nog nie klaar nie. As jy nou stop, word [name] nie geïnstalleer nie.%n%nWil jy Setup stop?
ConfirmUninstall=Wil jy %1 en al sy onderdele verwyder?
UninstallStatusLabel=Wag asseblief terwyl %1 van jou rekenaar verwyder word.
UninstalledAll=%1 is van jou rekenaar verwyder.

[CustomMessages]
DesktopIcon=Ikoon op die lessenaar
OllamaTask=Installeer Ollama (die KI; laai ±1,9 GB af)
OllamaDownloading=Laai Ollama af… %1 van %2 MB
OllamaInstalling=Installeer Ollama (die KI)…
OllamaFailed=Ollama kon nie geïnstalleer word nie:%n%1%n%nPreekverwerker is wel geïnstalleer. Installeer Ollama later van ollama.com; die Opstelling-lys in die app wys wanneer dit reg is.
OpenApp=Maak Preekverwerker oop
DeleteData=Vee ook die werkgids uit?%n%n%1%n%nDaarin is die afgelaaide dienste, instellings en die kanaal-koppeling. Jou gesnyde preke in die uitsetgids (bv. Videos\Preke) word nie uitgevee nie.%n%nKies Nee om dit te hou (as jy weer installeer, gaan jy voort waar jy was).

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopIcon}"; Flags: checkedonce
Name: "ollama"; Description: "{cm:OllamaTask}"; Check: NeedsOllama

[Files]
; Flutter bundle incl. plugin DLLs, libmpv and the VC++ runtime DLLs the workflow copies next to the exe.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\deps\yt-dlp.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\deps\qjs.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\deps\ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\deps\ffprobe.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Preekverwerker"; Filename: "{app}\preekverwerker.exe"
Name: "{userdesktop}\Preekverwerker"; Filename: "{app}\preekverwerker.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\preekverwerker.exe"; Description: "{cm:OpenApp}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; The uninstaller has no Restart Manager: close a running app (and its yt-dlp/ffmpeg) first.
Filename: "{sys}\taskkill.exe"; Parameters: "/F /T /IM preekverwerker.exe"; Flags: runhidden; RunOnceId: "CloseApp"

[Code]
// True when Ollama's per-user install is absent (the "ollama" task only shows then).
function NeedsOllama: Boolean;
begin
  Result := not FileExists(ExpandConstant('{localappdata}\Programs\Ollama\ollama.exe'));
end;

// Shows the download progress in the install page's status line.
function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  // One line on purpose: Inno reads any line starting with '[' as a section tag, even in [Code].
  WizardForm.StatusLabel.Caption := FmtMessage(CustomMessage('OllamaDownloading'), [IntToStr(Progress div 1048576), IntToStr(ProgressMax div 1048576)]);
  Result := True;
end;

// Downloads the pinned OllamaSetup (hash-checked) and runs it silently; a failure never aborts our install.
procedure InstallOllama;
var
  Code: Integer;
begin
  try
    DownloadTemporaryFile('https://github.com/ollama/ollama/releases/download/{#OllamaVersion}/OllamaSetup.exe',
      'OllamaSetup.exe', '{#OllamaSha256}', @OnDownloadProgress);
    WizardForm.StatusLabel.Caption := CustomMessage('OllamaInstalling');
    if not Exec(ExpandConstant('{tmp}\OllamaSetup.exe'), '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '',
      SW_HIDE, ewWaitUntilTerminated, Code) or (Code <> 0) then
      RaiseException('OllamaSetup exit ' + IntToStr(Code));
  except
    SuppressibleMsgBox(FmtMessage(CustomMessage('OllamaFailed'), [GetExceptionMessage]), mbError, MB_OK, IDOK);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('ollama') then
    InstallOllama;
end;

// After uninstall: offer to delete the work folder; default (and silent) is to keep it.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Dir: String;
begin
  Dir := ExpandConstant('{#DataDir}');
  if (CurUninstallStep = usPostUninstall) and DirExists(Dir) and not UninstallSilent then
    if MsgBox(FmtMessage(CustomMessage('DeleteData'), [Dir]), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      DelTree(Dir, True, True, True);
end;
