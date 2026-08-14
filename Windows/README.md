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
without a console window.

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
