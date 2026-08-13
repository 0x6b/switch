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

On first run, Switch creates and opens:

```text
%LOCALAPPDATA%\Switch\config.toml
```

Edit the generated mappings, then start Switch again. There is intentionally no
settings UI, tray icon, installer, automatic startup, or automatic config reload
yet. To stop it, use Task Manager or `Stop-Process Switch` in PowerShell.

The leader keystroke is consumed globally. Modified key combinations pass
through and cancel an in-progress sequence. A mapped key is consumed; an
unmapped key passes through.
