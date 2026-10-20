; Installer for the signed Python runtime. The shortcut starts pythonw.exe.

#define AppName "Trim Playlist"
#define AppVersion "0.1.0"
#define AppPublisher "Trim Playlist"
#ifndef SourceDir
  #define SourceDir "..\dist\plain-pack\TrimPlaylist"
#endif

[Setup]
AppId={{BE8EA07F-C02D-4559-ACE5-7C55B327440A}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Trim Playlist
DefaultGroupName=Trim Playlist
OutputDir=..\dist\setup-plain
OutputBaseFilename=TrimPlaylist-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\denia.ico
SetupIconFile=..\denia.ico
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion; Excludes: "TrimPlaylist.exe"

[Icons]
Name: "{autoprograms}\Trim Playlist"; Filename: "{app}\pythonw.exe"; Parameters: """{app}\pc\app\trim_playlist_app.py"""; WorkingDir: "{app}"; IconFilename: "{app}\denia.ico"
Name: "{autodesktop}\Trim Playlist"; Filename: "{app}\pythonw.exe"; Parameters: """{app}\pc\app\trim_playlist_app.py"""; WorkingDir: "{app}"; IconFilename: "{app}\denia.ico"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\pythonw.exe"; Parameters: """{app}\pc\app\trim_playlist_app.py"""; WorkingDir: "{app}"; Description: "Launch Trim Playlist"; Flags: nowait postinstall skipifsilent
