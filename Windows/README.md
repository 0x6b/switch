# Switch for Windows

The first Windows build is a small native leader-key launcher. Press the
configured leader key followed by a mapped key. Executable targets are brought
to the foreground when already running and launched otherwise; URLs are opened
with their default handler.

## Requirements

- Windows 11
- Rust stable with the `x86_64-pc-windows-msvc` toolchain
- MSVC v143 x64/x86 Build Tools and a Windows 11 SDK (the Visual Studio IDE is
  not required)

## Build and run

```powershell
cd Windows
cargo build --release
.\target\release\Switch.exe
```

When running Windows Cargo from a repository stored in WSL through a
`\\wsl.localhost\...` path, put Cargo's build output on the Windows filesystem.
The WSL filesystem does not support the lock used by incremental compilation:

```powershell
$env:CARGO_TARGET_DIR = "$env:LOCALAPPDATA\Switch\cargo-target"
cargo run
```

Set `CARGO_TARGET_DIR` in your PowerShell profile if you want this to persist.
With this override, a release binary is written to
`$env:CARGO_TARGET_DIR\release\Switch.exe` instead of the repository's `target`
directory.

Debug builds produced by `cargo run` stay attached to the console and stop with
<kbd>Ctrl</kbd>+<kbd>C</kbd>. Release builds use the Windows GUI subsystem and run
without a console window. Debug builds also log launcher resolution, visible
process paths, executable matching, and foreground activation results to the
console.

On first run, Switch creates and opens:

```text
%LOCALAPPDATA%\Switch\config.toml
```

Edit the generated mappings, then start Switch again. There is intentionally no
settings UI, tray icon, installer, automatic startup, or automatic config reload
yet. To stop it, use Task Manager or `Stop-Process Switch` in PowerShell.

## Install and start at login

Build a release and copy it to a stable location. Run the same commands again
to update an existing installation:

```powershell
$env:CARGO_TARGET_DIR = "$env:LOCALAPPDATA\Switch\cargo-target"
cargo build --release

Stop-Process -Name Switch -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force "$env:LOCALAPPDATA\Switch" | Out-Null
Copy-Item `
  "$env:CARGO_TARGET_DIR\release\Switch.exe" `
  "$env:LOCALAPPDATA\Switch\Switch.exe"

Start-Process "$env:LOCALAPPDATA\Switch\Switch.exe"
```

Create a shortcut in the current user's Startup folder to start Switch after
login:

```powershell
$startup = [Environment]::GetFolderPath("Startup")
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut("$startup\Switch.lnk")
$shortcut.TargetPath = "$env:LOCALAPPDATA\Switch\Switch.exe"
$shortcut.WorkingDirectory = "$env:LOCALAPPDATA\Switch"
$shortcut.Save()
```

Remove the shortcut to disable automatic startup:

```powershell
Remove-Item "$([Environment]::GetFolderPath('Startup'))\Switch.lnk"
```

## Targets

Use an executable path for a classic desktop app or a URL for the default web
browser:

```toml
[launcher.primary]
a = 'C:\Program Files\Alacritty\alacritty.exe'
g = 'https://github.com'
```

Microsoft Store and other packaged apps live under versioned paths in
`C:\Program Files\WindowsApps`, so do not map their executable paths. Find the
app's stable Application User Model ID (AUMID) instead:

```powershell
Get-StartApps | Where-Object Name -Match "Teams" | Format-Table Name, AppID
```

Prefix the returned `AppID` with `shell:AppsFolder\`:

```toml
[launcher.primary]
t = 'shell:AppsFolder\MSTeams_8wekyb3d8bbwe!MSTeams'
```

Use the `AppID` reported on your machine rather than assuming it matches this
example. A packaged app receives the launch request through Windows Shell and
normally activates its existing window when it is already running.

The leader keystroke is consumed globally. Modified key combinations pass
through and cancel an in-progress sequence. A mapped key is consumed; an
unmapped key passes through.
