# Switch

A personal macOS window switcher and app launcher. Replaces <kbd>Cmd</kbd>+<kbd>Tab</kbd> with a list of individual windows instead of apps, and opens mapped apps and URLs with a leader key.

![Screenshot](./docs/switch.png)

## Window Switcher

Hold <kbd>Cmd</kbd> and press <kbd>Tab</kbd> to open the switcher. Keep <kbd>Cmd</kbd> held while you navigate, then release it to activate the highlighted window.

Use <kbd>Opt</kbd>+<kbd>Tab</kbd> instead for windows of the current app only.

The list is grouped: on-screen first, then **Minimized**, then **Hidden**. Picking a minimized or hidden row un-minimizes / un-hides before raising.

### Switching

While the switcher is open with the modifier held:

| Key                                                                                                                                | Action                                |
| ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| <kbd>Tab</kbd> / <kbd>Shift</kbd> + <kbd>Tab</kbd>, <kbd>↓</kbd> / <kbd>↑</kbd>, <kbd>j</kbd>/<kbd>k</kbd>, Two-finger swipe ↓ / ↑ | Next / previous row                   |
| <kbd>w</kbd> / <kbd>q</kbd> / <kbd>h</kbd> / <kbd>m</kbd>                                                                          | Close window / Quit / Hide / Minimize |
| <kbd>s</kbd>                                                                                                                       | Switch to filter-typing mode          |
| <kbd>,</kbd>                                                                                                                       | Open Settings                         |
| Release modifier, or mouse click                                                                                                   | Activate selected, close panel        |
| <kbd>Escape</kbd>                                                                                                                  | Cancel                                |

In filter mode (modifier may be released), the navigation/activation keys still apply, plus:

| Key                                                | Action                         |
| -------------------------------------------------- | ------------------------------ |
| Letters / digits                                   | Append to filter, list narrows |
| <kbd>Backspace</kbd>, <kbd>Ctrl</kbd>+<kbd>H</kbd> | Delete one character           |
| <kbd>Ctrl</kbd>+<kbd>W</kbd>                       | Delete previous word           |
| <kbd>Enter</kbd>                                   | Activate selected              |

Matching is case- and diacritic-insensitive substring. Whitespace splits the filter into tokens that must all match.

### Placement

While the switcher is open with the modifier held, these keys focus the selected window and move it on its current screen (ported from [Rectangle](https://github.com/rxhanson/Rectangle)). The panel stays open, so placements can be chained or followed by more navigation.

| Key                                                                                           | Action                             |
| --------------------------------------------------------------------------------------------- | ---------------------------------- |
| <kbd>←</kbd> / <kbd>→</kbd>                                                                   | Left / right half                  |
| <kbd>Ctrl</kbd>+<kbd>←</kbd> / <kbd>Ctrl</kbd>+<kbd>→</kbd>                                   | Top-left / top-right quarter       |
| <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>←</kbd> / <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>→</kbd> | Bottom-left / bottom-right quarter |
| <kbd>Ctrl</kbd>+<kbd>c</kbd>                                                                  | Center (size unchanged)            |
| <kbd>Ctrl</kbd>+<kbd>n</kbd>                                                                  | Move to next display, centered     |

Repeating a half or quarter command on the same window cycles its width through 1/2 → 2/3 → 1/4 → 1/3 of the screen. Moving the window by hand, or running a different command, restarts the cycle at 1/2.

## Launcher

An optional leader-key launcher, independent of the window switcher and ported from [app-activate](https://github.com/0x6b/app-activate). Press the leader key, then a mapped key within the timeout, to open the mapped target. Press the leader key twice to use the secondary mapping set. Disabled until a leader key is recorded in Settings.

A target is either an app bundle path (launched, or brought to front if running) or a URL such as `cleanshot://capture-window`.

> [!NOTE]
>
> - The leader keystroke is consumed system-wide; the frontmost app never sees it. Keys pressed with Cmd/Opt/Ctrl/Shift pass through untouched.
> - The launcher is inactive while the switcher is open and while the Settings window is active (so the key recorder can capture the leader key).

## Settings

Press <kbd>,</kbd> with the modifier held while the switcher is open to open the Settings window. It has:

- **Launch at login**: macOS may report it requires approval; enable the entry in **System Settings** → **General** → **Login Items & Extensions**.
- **Quit Switch**: also <kbd>Cmd</kbd>+<kbd>Q</kbd> while the Settings window is focused.
- **Launcher**: the leader key, the timeout, and the key-to-target mapping table. See [Launcher](#launcher).

## Install

Download the latest `Switch-<version>.zip` with the [GitHub CLI](https://cli.github.com/) and unzip it:

```console
$ gh release download --repo 0x6b/switch --pattern 'Switch-*.zip'
$ unzip -o Switch-*.zip -d ~/bin
```

`gh` (and `curl`) don't set the quarantine flag, so the app launches without a Gatekeeper prompt.

The app is not notarized. If you download the zip through a browser instead, macOS quarantines it; strip the flag before launching:

```console
$ xattr -dr com.apple.quarantine ~/bin/Switch.app
```

## Accessibility

Switch installs a session-level `CGEvent` tap and reads other apps' windows via the Accessibility APIs, so macOS requires Accessibility permission. On first launch it prompts and quits. Grant access in **System Settings** → **Privacy & Security** → **Accessibility**, then relaunch.

## Build

Requires macOS 26+, Xcode 26+, and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```console
$ brew install xcodegen
$ make            # list every target
$ make test       # Run the test suite
$ make build      # Build a release into ./build
$ make install    # Test, build, and copy Switch.app to ~/bin
$ make clean      # Remove ./build
```

The build is ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`), so every rebuild changes the code hash. After rebuilding, remove and re-add the entry in the Accessibility list, otherwise the tap silently receives no events.

## How to Contribute

This is my switcher. I'll maintain it as long as it meets my needs, or until I find a better alternative. I'm not looking for contributions, but I'm sharing the code in case it helps someone else. Please feel free to fork it and modify it however you like. I'm not interested in making this:

- more capable
- more configurable
- more user-friendly
- more attractive
- more popular
- cross-platform (beyond my future use)

There should be similar and/or more capable tools available in every language and platform, so if you have a better option, feel free to keep using that.

## Motivation

I'm a loyal user of [Contexts](https://contexts.co/), which has the window-level switching model I want, for 10 years. However its last update was [2022-08-27](https://contexts.co/whats-new/) and the future of the app is uncertain although it's totally working fine on my Mac at this time of writing. I wanted to create a plan B in case it stops working in the future. This repository is my attempt to create a similar app just solely for my own use case.

The launcher absorbs my separate [app-activate](https://github.com/0x6b/app-activate) daemon, so one process handles both switching and launching.

## License

MIT. See [LICENSE](LICENSE).

App icon: [`swatch-book`](https://lucide.dev/icons/swatch-book) from [Lucide](https://lucide.dev) ([ISC](https://github.com/lucide-icons/lucide/blob/main/LICENSE)).
