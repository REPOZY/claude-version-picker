# Claude Code Version Picker

A lightweight Windows wrapper that turns the `claude` command into a version chooser — keeping a pinned stable version for daily work while giving you instant access to the latest release.

```
PS> claude

Choose Claude Code version:
  1) v2.1.91     Pinned daily-work version
  2) latest      Current installed version
  d) doctor      Diagnostics
  h) help        Help
  q) quit
Choose:
```

## Why

Anthropic ships Claude Code updates frequently. New versions bring access to newer models (e.g. Opus 4.7 requires v2.1.111+), but a recurring pattern in the Claude Code community is that certain updates change agentic behaviour in ways that feel less reliable for complex, multi-step work — things like long-horizon planning, context management across large codebases, following multi-part instructions without drift, and unexpectedly high token consumption within a single session.

Analysis of the [official Claude Code changelog](https://code.claude.com/docs/en/changelog), cross-referenced with community reports across GitHub issues, Reddit (r/ClaudeAI, r/LocalLLaMA), Hacker News, and X/Twitter, surfaces the following picture.

### The one confirmed CLI-level behavioral change

**v2.1.94 (April 7) changed the default effort level from `medium` to `high`** for all non-Pro users (API key, Bedrock, Vertex, Team, Enterprise). This is the only change in the changelog that maps directly and unambiguously to the "heavier, more token-hungry, more overthinky" complaints. It is a CLI-level default — not a model-level change — and it is **fully configurable**: every version from v2.1.76 onward supports `/effort medium` to restore the lighter behavior, regardless of which CLI version you are running.

The practical implication: you do not need to pin an old binary to get the old effort behavior. You can run the latest version and type `/effort medium` (or set it in `settings.json` as `"effort": "medium"`) and get the same result.

### Version recommendations

**v2.1.110 — best all-around.** The last release before Opus 4.7 (introduced in v2.1.111), with all security and stability fixes from April 7–15 included. The effort default is `high` from v2.1.94, but `/effort medium` restores lighter behavior. Recommended for users who want a mature, well-tested binary without the Opus 4.7 transition and without sacrificing security hardening.

**v2.1.91 — maximum conservatism, with tradeoffs.** Predates the effort default change and the Bedrock auth regression (both v2.1.94). Effort is `medium` by default — no extra configuration needed. The cost is real: v2.1.91 misses significant security fixes introduced in v2.1.98, including a Bash tool permission bypass where a backslash-escaped flag could be auto-allowed as read-only and enable arbitrary code execution, and hardened checks for compound commands and network redirects. Appropriate for personal and hobby use where agentic security is not a concern. Not recommended for production, CI, or enterprise contexts.

> **Important nuance:** a majority of "worse planning / lazier / heavier" complaints in the community are actually tied to model and serving changes on Anthropic's side — changes that affect all CLI versions equally and cannot be avoided by pinning any specific binary. The CLI version controls defaults and tooling; it does not pin the model's reasoning behaviour. No pinned CLI version is a guarantee against model-level regressions.

This picker makes it easy to keep your preferred stable binary for day-to-day work while having the latest version available for when you need newer models or features — without any manual PATH swapping or re-installing.

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

- `versions\claude-v2.1.91.exe` — versioned name (auto-detected, label shown in menu)
- `versions\claude-old.exe` — generic name (also auto-detected)

**Option A — you already have the version installed right now**

```powershell
# Save your current install as the pinned binary
Copy-Item "$env:USERPROFILE\.local\bin\claude.exe" "C:\Tools\claude-version-picker\versions\claude-old.exe"

# Then update to the latest
irm https://claude.ai/install.ps1 | iex

# If the latest binary still reports the old version, force it
& "$env:USERPROFILE\.local\bin\claude.exe" install latest --force
```

Then skip to Step 3.

**Option B — you need to retrieve a specific older version from scratch**

```powershell
# 1. Temporarily install the version you want to pin
#    See the Why section above for guidance on which version to choose
& ([scriptblock]::Create((irm https://claude.ai/install.ps1))) -Target 2.1.91

# 2. Verify the version is correct before copying
& "$env:USERPROFILE\.local\bin\claude.exe" --version

# 3. Copy it to the versions folder (use the version number in the filename)
Copy-Item "$env:USERPROFILE\.local\bin\claude.exe" "C:\Tools\claude-version-picker\versions\claude-v2.1.91.exe"

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
$env:CLAUDE_SWITCHER_OLD = 'D:\backups\claude-v2.1.91.exe'
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

## Uninstalling

The picker is entirely self-contained — removing it restores your terminal to using Claude Code directly, and your Claude Code installations are not touched at any point.

**Step 1 — Remove the picker folder from PATH**

```powershell
$pickerPath = 'C:\Tools\claude-version-picker'   # adjust if you used a different folder
$current = [Environment]::GetEnvironmentVariable('Path', 'User')
$updated = ($current -split ';' | Where-Object { $_ -ne $pickerPath }) -join ';'
[Environment]::SetEnvironmentVariable('Path', $updated, 'User')
Write-Host "Removed from PATH. Open a new terminal to apply."
```

Close all open CMD and PowerShell windows after running this.

**Step 2 — Optionally save your pinned binary elsewhere**

The `versions\` folder contains your pinned binary (e.g. `claude-v2.1.91.exe`). If you want to keep it as a backup before deleting the folder, copy it somewhere safe first:

```powershell
Copy-Item 'C:\Tools\claude-version-picker\versions\claude-v2.1.91.exe' "$env:USERPROFILE\Desktop\claude-v2.1.91.exe"
```

Skip this step if you don't need the backup.

**Step 3 — Delete the picker folder**

```powershell
Remove-Item -Recurse -Force 'C:\Tools\claude-version-picker'
```

**Step 4 — Verify**

Open a fresh terminal and run:

```
where.exe claude
```

It should now show only your Claude Code install at `%USERPROFILE%\.local\bin\claude.exe`. Running `claude` will launch Claude Code directly, with no version menu.

## License

[MIT](LICENSE)
