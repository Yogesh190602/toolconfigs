# arch-setup

Reproduce this Arch Linux + GNOME machine on a new box: packages, dotfiles, and
GNOME settings. Two scripts:

| Script | Where you run it | What it does |
|--------|------------------|--------------|
| `capture.sh` | **this** (source) machine | Snapshots packages, dotfiles, dconf into `packages/`, `dotfiles/`, `dconf/`, then regenerates `install.sh`. Re-run anytime to refresh. |
| `install.sh` | the **new** machine | Installs everything and symlinks the dotfiles back into `$HOME`. **Self-contained** — see below. |

## Quick start on a new machine

`install.sh` is self-contained — the package lists, every dotfile and the GNOME
dconf dump are embedded in it. Copy that one file across and run it:

```bash
scp install.sh newbox:~/            # or curl it, or put it on a USB stick
ssh newbox
./install.sh --dry-run   # preview every action, changes nothing
./install.sh             # do it (run as your normal user, NOT root)
```

Cloning the repo works too, and is preferred if you plan to keep editing the
configs — `install.sh` detects `packages/`, `dotfiles/` and `dconf/` next to it
and uses those instead of its embedded copy:

```bash
git clone <this-repo> ~/arch-setup && cd ~/arch-setup && ./install.sh
```

### How the self-contained mode works

Run standalone, `install.sh` unpacks its embedded files to
`~/.local/share/arch-setup` (override with `ARCH_SETUP_DIR`) and symlinks your
dotfiles out of there. **That directory is permanent** — deleting it leaves the
symlinks in `$HOME` dangling. A `--dry-run` unpacks to a temp dir instead and
cleans up after itself.

`install.sh` is **generated**. Edit `install-template.sh` for logic and re-run
`capture.sh`; direct edits to `install.sh` are overwritten. The generator embeds
each file as a quoted heredoc, restoring empty directories and files captured
without a trailing newline, and refuses to emit a script that fails `bash -n`.

## What gets installed

Packages are stored **categorized** — open `packages/pacman-explicit.txt` to see
them grouped under `## Category` headers (Security-Recon, Security-Web,
Security-Cracking, Security-Forensics, Terminal-CLI, Dev-Tools, GNOME-Desktop,
System-Base, Apps, …). The `#` lines are comments; the installer ignores them.

- `packages/pacman-explicit.txt` — native repo packages (installed)
- `packages/blackarch.txt` — packages from the BlackArch repo; `install.sh`
  runs the BlackArch `strap.sh` bootstrap first
- `packages/aur.txt` — AUR/foreign packages via `yay` (best-effort; a package
  with no AUR PKGBUILD is skipped rather than aborting)
- `packages/pacman-all.txt` — **reference only**, the full dependency-inclusive
  list for verification. Never installed directly (doing so would mark every
  dependency as explicit and break orphan detection).
- `packages/pacman-explicit-flat.txt` — the flat explicit list, filtered the
  same way as the categorized files so it can be diffed against them without
  the excluded packages showing up as drift.

- `packages/extras.txt` — hand-maintained packages the **captured configs
  need** but that weren't installed on the source machine (JetBrainsMono Nerd
  Font for Ghostty; `ripgrep` + `fd` for LazyVim/Telescope). `capture.sh` never
  touches this file. Installed after the main list.
- `packages/{npm-global,cargo,go-bin,uv-tools}.txt` — language-level globals,
  **captured but not auto-installed**. Review and install what you want.

**Never captured**, because capturing them breaks the install:

- the AUR helper itself (`yay`, `yay-bin`, `paru`, …) — `install.sh` bootstraps
  `yay-bin` in step 2, and the BlackArch `yay` package conflicts with it, so
  recording either one aborts the whole pacman transaction
- `*-debug` packages — local build leftovers with no PKGBUILD to reinstall from

**Conflicts don't abort the run.** A single bad package (an already-installed
AUR build conflicting with a repo one, say `visual-studio-code-bin` vs `code`)
would otherwise take down the entire `pacman -S` transaction. So `install.sh`
tries the fast bulk install, and on failure retries one package at a time,
then prints what it had to skip.

## Dotfiles

Curated wish-list (`.zshrc .zprofile .bashrc .bash_profile .gitconfig` and
`.config/{git,nvim,ghostty,rofi,wofi,fish,gh,Code/User}`) is captured — anything
absent on the source machine is skipped with a warning — then **symlinked** from
this repo into `$HOME`. Anything real already in the way is moved to
`~/.pre-setup-backup-<timestamp>/` first — nothing is overwritten blindly.
oh-my-zsh is reinstalled from upstream, not copied. The two custom zsh plugins
referenced by `.zshrc` (`zsh-autosuggestions`, `zsh-syntax-highlighting`) are
git-cloned into `$ZSH_CUSTOM/plugins/` automatically.

**Neovim:** the full LazyVim config ships with `lazy-lock.json`, so on first
`nvim` launch all plugins install at their pinned versions. `ripgrep`/`fd` (from
`extras.txt`) back Telescope; Mason installs LSP servers on first run.

## zsh theme (`zsh-theme/`)

`zeroday` — a custom oh-my-zsh theme built from artwork, in the image's own
colours. Prompt is `<cat> dir [branch] ▸`, with a skull on a dirty git tree and
another on the right carrying any non-zero exit code.

| Path | Installs to | Why |
|------|-------------|-----|
| `zeroday.zsh-theme` | `$ZSH_CUSTOM/themes/` | in `custom/`, so `omz update` can't clobber it |
| `fonts/ZeroDayGlyphs.ttf` | `~/.local/share/fonts/` + `fc-cache` | colour-bitmap (CBDT) font holding the prompt face |
| `zeroday/` | `~/.local/share/zeroday/` | artwork, renderers, `build.sh` |

**Copied, not symlinked** like the dotfiles: fontconfig only scans real
directories, and `zeroday-build` rewrites the artwork in place.

**The prompt face is a font glyph, not an emoji.** A terminal can't put an image
in a prompt — the prompt is redrawn on every keystroke and inline images aren't
part of the character grid. So the cat is sliced across two Private Use
codepoints (U+E900/U+E901). A cell is roughly 1:2, so two side by side form one
square picture, and zsh still measures the prompt as exactly 2 columns.
`.zshrc` selects them via `ZERODAY_FACE`; set it to an emoji to opt out.

After installing, **fully restart the terminal** (not just a new tab) so it
rescans fonts. Two empty boxes in the prompt means the font wasn't found.

```
zeroday                              # banner: half-block artwork + tagline
zeroday-sticker [rows]               # the real PNG via the Kitty graphics
                                     # protocol (Ghostty/kitty; else banner)
zeroday-build <img> [rows] [crop]    # re-skin the theme from any image
```

Re-skinning needs `imagemagick` (in `extras.txt`). Rebuilding the *font* also
needs `fonttools` + `pillow` in a venv that is **not** tracked:

```bash
cd zsh-theme/zeroday
python -m venv venv && venv/bin/pip install fonttools pillow
venv/bin/python mkfont.py face.png ZeroDayGlyphs.ttf 2
```

The theme's PNGs and TTF are binary, which a quoted heredoc can't carry, so the
generated `install.sh` ships them **base64-encoded** (`_b64file`) while text
files stay as plain heredocs (`_file`).

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
