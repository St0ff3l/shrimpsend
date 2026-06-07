; Inno Setup 6 — 官网渠道安装向导（可选安装路径 + 默认勾选桌面快捷方式）。
; 通常由 app/scripts/package_windows.ps1 调用 ISCC 并传入 /D 参数；也可手动编译：
;   cn:   ... /DRegionSlug=cn /DIsCnBuild=1 scripts\shrimpsend_windows_inno.iss
;   intl: ... /DRegionSlug=intl scripts\shrimpsend_windows_inno.iss
; 本文件须 UTF-8 BOM；显示名在脚本内定义，勿经 ISCC /D 传中文。

#ifndef ReleaseDir
#define ReleaseDir "..\..\app\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
#define OutputDir "inno_output"
#endif
#ifndef MyAppVersion
#define MyAppVersion "1.0.0"
#endif
#ifndef RegionSlug
; cn = 国内发行包，intl = 出海发行包（与 package_windows.ps1 产物命名一致）
#define RegionSlug "cn"
#endif

#ifdef IsCnBuild
#define MyAppDisplayName "虾传"
#define MyAppExeName "虾传.exe"
#else
#define MyAppDisplayName "Shrimpsend"
#define MyAppExeName "Shrimpsend.exe"
#endif

#define MyAppInstallFolder "Shrimpsend"
#define MyAppPublisher "Ultrasend"

[Setup]
AppId={{A8F3E8B1-6D2C-4E9F-9B1A-0C2D3E4F5A6B}
AppName={#MyAppDisplayName}
AppVersion={#MyAppVersion}
VersionInfoVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
; 允许用户在向导中选择安装目录（非 MSIX）
DisableDirPage=no
DefaultDirName={autopf}\{#MyAppInstallFolder}
UsePreviousAppDir=yes
DisableProgramGroupPage=yes
WizardStyle=modern
OutputDir={#OutputDir}
OutputBaseFilename=ShrimpsendSetup-{#RegionSlug}-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; 安装结束时显示说明（含 {app} 实际路径）
InfoAfterFile=install_notes_inno.txt

[Languages]
; 仅使用安装器自带的 Default.isl：精简版 Inno 往往不带 ChineseSimplified.isl（需从官网单独下载语言包）。
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
; 默认勾选：创建桌面快捷方式
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; 排除误落在 Release 目录的 *.msix（正式产物只在 dist；不应打进 exe 安装包）
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "*.msix"

#ifdef IsCnBuild
[InstallDelete]
; 覆盖升级：移除旧版英文主程序，避免与 虾传.exe 并存
Type: files; Name: "{app}\Shrimpsend.exe"
#endif

[Icons]
; 显式指定从安装目录下的 exe 取图标（索引 0），避免快捷方式仍显示缓存中的 Flutter 默认壳图标。
Name: "{autoprograms}\{#MyAppDisplayName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; IconIndex: 0
Name: "{autodesktop}\{#MyAppDisplayName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; IconIndex: 0; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppDisplayName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
