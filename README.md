# arch-setup

Reproduce this Arch Linux + GNOME machine on a new box: packages, dotfiles, and
GNOME settings. Two scripts:

| Script | Where you run it | What it does |
|--------|------------------|--------------|
| `capture.sh` | **this** (source) machine | Snapshots packages, dotfiles, dconf into `packages/`, `dotfiles/`, `dconf/`. Re-run anytime to refresh. |
| `install.sh` | the **new** machine | Installs everything and symlinks the dotfiles back into `$HOME`. |

## Quick start on a new machine

```bash
git clone <this-repo> ~/arch-setup && cd ~/arch-setup
./install.sh --dry-run   # preview every action, changes nothing
./install.sh             # do it (run as your normal user, NOT root)
```

## What gets installed

Packages are stored **categorized** — open `packages/pacman-explicit.txt` to see
them grouped under `## Category` headers (Security-Recon, Security-Web,
Security-Cracking, Security-Forensics, Terminal-CLI, Dev-Tools, GNOME-Desktop,
System-Base, Apps, …). The `#` lines are comments; the installer ignores them.

- `packages/pacman-explicit.txt` — native repo packages (installed)
- `packages/blackarch.txt` — packages from the BlackArch repo; `install.sh`
  runs the BlackArch `strap.sh` bootstrap first (dirsearch, ffuf, sherlock,
  enum4linux, stegseek)
- `packages/aur.txt` — AUR/foreign packages via `yay` (best-effort; junk like
  `*-debug` and local-only builds are skipped rather than aborting)
- `packages/pacman-all.txt` — **reference only**, the full dependency-inclusive
  list for verification. Never installed directly (doing so would mark every
  dependency as explicit and break orphan detection).
- `packages/{npm-global,cargo,go-bin,uv-tools}.txt` — language-level globals,
  **captured but not auto-installed**. Review and install what you want.

## Dotfiles

Curated set (`.zshrc .zprofile .bashrc .bash_profile .gitconfig` and
`.config/{git,nvim,ghostty,rofi,wofi,fish,gh,Code/User}`) is **symlinked** from
this repo into `$HOME`. Anything real already in the way is moved to
`~/.pre-setup-backup-<timestamp>/` first — nothing is overwritten blindly.
oh-my-zsh is reinstalled from upstream, not copied.

## GNOME

`dconf/gnome.ini` holds dumps of `/org/gnome/desktop/`,
`/org/gnome/shell/keybindings/`, and `/org/gnome/settings-daemon/` — restored on
install. Monitor-specific and wallpaper-path keys are intentionally excluded.

## Secrets — NOT captured (by design)

`~/.ssh`, `~/.gnupg`, `~/.aws`, API tokens, and the gh `hosts.yml` OAuth token
are excluded. `capture.sh` also greps the captured tree and aborts if anything
that looks like a key/token slipped through. After install, supply these
yourself — `install.sh` prints a checklist at the end (`gh auth login`, copy
`~/.ssh` from a secure backup, `chsh -s /usr/bin/zsh`, add yourself to the
`docker` group, reboot).
