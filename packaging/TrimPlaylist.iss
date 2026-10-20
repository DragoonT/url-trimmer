; Build with Inno Setup 6 on Windows:
;   iscc packaging\TrimPlaylist.iss

#define AppName "Trim Playlist"
#define AppVersion "0.1.0"
#define AppPublisher "Trim Playlist"
#define AppExeName "TrimPlaylist.exe"
#ifndef SourceDir
  #define SourceDir "..\dist\TrimPlaylist"
#endif

[Setup]
AppId={{BE8EA07F-C02D-4559-ACE5-7C55B327440A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Trim Playlist
DefaultGroupName=Trim Playlist
OutputDir=..\dist\installer
OutputBaseFilename=TrimPlaylist-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#AppExeName}
SetupIconFile=..\denia.ico
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autoprograms}\Trim Playlist"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\Trim Playlist"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch Trim Playlist"; Flags: nowait postinstall skipifsilent
