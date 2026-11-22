# Linux on Windows

A lightweight Windows PowerShell utility for installing, managing, and removing Windows Subsystem for Linux (WSL 2).

It provides a graphical interface with automatic and guided installation workflows, distro selection, status checks, and optional cleanup tools.

## Features

- **WSL 2 setup** — enables the required Windows optional features, updates WSL, and sets WSL 2 as the default.
- **Distro selection** — choose a distribution such as Ubuntu, Debian, Kali Linux, or openSUSE, or enter a distro name manually.
- **Auto install** — run the main setup workflow with one confirmation.
- **Custom install** — execute each setup step individually.
- **Status checks** — view WSL status and installed distributions.
- **Removal tools** — choose individual cleanup tasks or run the full removal workflow.
- **Multilingual interface** — Vietnamese, English, Japanese, and Lao.
- **Language persistence** — the desktop utility remembers the selected language; the web page remembers the visitor's language when browser storage is available.

## Requirements

- Windows 10 (version 2004 or later) or Windows 11.
- 64-bit Windows.
- Administrator privileges for enabling/disabling Windows features and system-level installation or removal.
- Hardware virtualization enabled in UEFI/BIOS for WSL 2.
- An internet connection to download WSL components, Linux distributions, or remote locale files.

## Quick start

### Option 1: Run from the hosted script

Open PowerShell and run:

```powershell
irm https://wsl.tino.io.vn/linux.ps1 | iex
```

If PowerShell is not already elevated, the utility asks whether to relaunch with Administrator privileges.

### Option 2: Run from GitHub

Download or clone this repository:

```powershell
git clone https://github.com/minhduc290613/linux-on-windows.git
cd linux-on-windows
.\linux.ps1
```

Keep the `locales` directory beside `linux.ps1` when running locally so the language files can be loaded without downloading them.

## Supported languages

| Code | Language | Locale file |
|---|---|---|
| VN | Vietnamese | `locales/vn.json` |
| EN | English | `locales/en.json` |
| JP | Japanese | `locales/jp.json` |
| LAO | Lao | `locales/lao.json` |

When launched through `irm ... | iex`, locale files are fetched from the configured hosting URL first, with a GitHub raw-content fallback. Missing translation keys fall back to Vietnamese.

## Installation workflow

The Auto workflow performs the following operations:

1. Enables `VirtualMachinePlatform`.
2. Enables `Microsoft-Windows-Subsystem-Linux`.
3. Runs `wsl --update`.
4. Sets WSL 2 as the default version.
5. Installs the selected Linux distribution.

The Custom workflow exposes these steps individually so users can inspect and run them separately.

## Removal and data-loss warning

The removal tools are powerful and can permanently delete Linux environments and their data.

- `wsl --unregister` removes a distribution and its virtual disk data.
- Disabling Windows optional features may require a restart.
- Full cleanup can remove WSL packages, the WSL installation directory, Explorer integration, and selected user cache/configuration files.
- The optional user-cache cleanup removes `.wslconfig` and Canonical package data.

**Back up important Linux files before using any removal option.** Review the selected tasks and confirmation dialog carefully. Do not run full removal unless you intend to remove all affected WSL distributions and components.

## Repository layout

```text
linux-on-windows/
├── index.html
├── style.css
├── linux.ps1
└── locales/
    ├── vn.json
    ├── en.json
    ├── jp.json
    └── lao.json
```

## Notes

- The web page is a landing page and interactive overview; the Windows management utility is `linux.ps1`.
- The script requires Windows PowerShell with Windows Forms support.
- WSL installation behavior depends on the Windows version, available virtualization support, network access, and Microsoft's WSL package availability.
- Review the script before executing it, especially when using a remote `irm ... | iex` command.

## License

No license file is currently included in this repository. Unless a license is added, the source code remains subject to the repository owner's default copyright; reuse and redistribution permissions are not explicitly granted.

## Author

**minhduc290613**

- GitHub: https://github.com/minhduc290613
- Repository: https://github.com/minhduc290613/linux-on-windows
