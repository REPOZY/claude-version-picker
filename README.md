# Claude Code Version Picker

A lightweight Windows wrapper that turns the `claude` command into a version chooser — keeping a pinned stable version for daily work while giving you instant access to the latest release.

```
PS> claude

Choose Claude Code version:
  1) v2.1.63     Pinned daily-work version
  2) latest      Current installed version
  d) doctor      Diagnostics
  h) help        Help
  q) quit
Choose:
```

## Why

Anthropic ships Claude Code updates frequently. New versions bring new models (e.g. Opus 4.7 requires v2.1.111+) but can occasionally change behaviour in ways that affect ongoing work. This picker lets you stay on a known-good version day-to-day while keeping the latest available whenever you need it — no re-installing, no PATH juggling by hand.

## How it works

Two files — `claude.cmd` and `claude.ps1` — live in a folder placed **first in your PATH**. When you type `claude`, Windows finds the picker before the real binary, shows the menu, then launches whichever version you chose. The two versions live at completely separate paths and never interfere with each other.

## Requirements

- **Windows** — CMD or PowerShell (this tool is Windows-only)
- **Git for Windows** — recommended by Anthropic for Claude Code on Windows
- **Claude Code** installed at `%USERPROFILE%\.local\bin\claude.exe` (the default native install path)
- **A saved copy** of the older Claude Code version you want to pin (see Setup)

## Setup

### Step 1 — Clone or download this repo

```powershell
git clone https://github.com/REPOZY/claude-version-picker.git C:\Tools\claude-version-picker
```

You can clone to any folder. The examples below use `C:\Tools\claude-version-picker` — adjust the path throughout if you choose differently.

---

### Step 2 — Get a pinned binary

You need a standalone `.exe` for the version you want to freeze. Place it in the `versions\` folder as either:

- `versions\claude-v2.1.63.exe` — versioned name (auto-detected, label shown in menu)
- `versions\claude-old.exe` — generic name (also auto-detected)

**Option A — you already have the version installed right now**

```powershell
Copy-Item "$env:USERPROFILE\.local\bin\claude.exe" "C:\Tools\claude-version-picker\versions\claude-old.exe"
```

Then install the latest normally and skip to Step 3.

**Option B — you need to retrieve a specific older version from scratch**

```powershell
# 1. Temporarily install the version you want to pin
& ([scriptblock]::Create((irm https://claude.ai/install.ps1))) -Target 2.1.63

# 2. Verify the version is correct before copying
& "$env:USERPROFILE\.local\bin\claude.exe" --version

# 3. Copy it to the versions folder (use the version number in the filename)
Copy-Item "$env:USERPROFILE\.local\bin\claude.exe" "C:\Tools\claude-version-picker\versions\claude-v2.1.63.exe"

# 4. Reinstall the latest
irm https://claude.ai/install.ps1 | iex

# 5. If the latest binary still reports the old version, force it
& "$env:USERPROFILE\.local\bin\claude.exe" install latest --force
```

> The `--force` step in (5) is needed when `DISABLE_AUTOUPDATER=1` is set in your Claude Code `settings.json`. Without it the bootstrap reports success but the binary on disk is not replaced.

---

### Step 3 — Add the picker folder to PATH

The picker folder must appear **before** `%USERPROFILE%\.local\bin` in your user PATH so Windows finds it first.

```powershell
$pickerPath = 'C:\Tools\claude-version-picker'   # adjust if you used a different folder
$current = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (($current -split ';') -contains $pickerPath)) {
    [Environment]::SetEnvironmentVariable('Path', "$pickerPath;$current", 'User')
    Write-Host "PATH updated. Open a new terminal to apply."
} else {
    Write-Host "Already in PATH."
}
```

Close **all** open CMD and PowerShell windows after running this.

---

### Step 4 — Verify

Open a **fresh** terminal and run all four checks:

```
where.exe claude           # picker folder must appear first in the list
claude doctor              # both binaries must be found with correct versions
claude old --version       # must show your pinned version
claude latest --version    # must show your current latest version
```

Then run `claude` to see the chooser menu.

---

## Usage

```
claude          Show the version picker menu
claude old      Launch the pinned version directly (skip menu)
claude latest   Launch the latest version directly (skip menu)
```

Any unrecognised arguments are passed through to the latest binary unchanged:

```
claude chat "hello"   →  runs: <latest binary> chat "hello"
claude --help         →  runs: <latest binary> --help
```

## Commands

| Command | Description |
|---|---|
| `claude` | Show version picker menu |
| `claude old` | Launch pinned version directly |
| `claude latest` | Launch latest version directly |
| `claude doctor` | Show paths and detected versions for both binaries |
| `claude help` | Show help text |

## Updating "latest"

The pinned binary in `versions\` never changes automatically. The "latest" slot always reflects whatever is at `%USERPROFILE%\.local\bin\claude.exe`.

To update to a newer Claude Code release:

```powershell
irm https://claude.ai/install.ps1 | iex
```

If you have `DISABLE_AUTOUPDATER=1` in your `settings.json`, add `--force`:

```powershell
& "$env:USERPROFILE\.local\bin\claude.exe" install latest --force
```

The picker picks up the updated binary automatically — no other changes needed.

## Configuration

Two environment variables let you override the auto-detected paths:

| Variable | Purpose |
|---|---|
| `CLAUDE_SWITCHER_OLD` | Full path to your pinned binary |
| `CLAUDE_SWITCHER_LATEST` | Full path to your latest binary |

Set them for a single session:

```powershell
$env:CLAUDE_SWITCHER_OLD = 'D:\backups\claude-v2.1.63.exe'
```

Or add them permanently via **System Properties → Environment Variables**.

## Binary search order

**Pinned ("old") — first match wins:**
1. `CLAUDE_SWITCHER_OLD` environment variable
2. First `versions\claude-v*.exe` file found (sorted alphabetically)
3. `versions\claude-old.exe`
4. `%APPDATA%\npm\claude.cmd` (legacy npm install fallback)

**Latest — first match wins:**
1. `CLAUDE_SWITCHER_LATEST` environment variable
2. `%USERPROFILE%\.local\bin\claude.exe` ← default native install path
3. `%LOCALAPPDATA%\Claude Code\claude.exe`

## Troubleshooting

**`claude` launches without showing the menu**
The picker is not first in PATH. Run `where.exe claude` — if the picker folder is not the first result, re-run Step 3 and open a fresh terminal.

**"Pinned binary not found" error**
No matching file was found in `versions\`. Check that your binary is named `claude-old.exe` or `claude-v<version>.exe` and is inside the `versions\` folder.

**Latest binary still shows old version after reinstalling**
Run `& "$env:USERPROFILE\.local\bin\claude.exe" install latest --force`. This happens when `DISABLE_AUTOUPDATER=1` is set.

**Diagnostics**
Run `claude doctor` — it shows the exact paths and versions the picker has resolved, plus the output of `where.exe claude`.

## License

[MIT](LICENSE)
