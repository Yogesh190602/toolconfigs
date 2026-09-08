#!/usr/bin/env bash
# capture.sh — snapshot THIS Arch machine into ./packages, ./dotfiles, ./dconf
# Run on the source machine. Regenerates everything the installer consumes.
# Safe to re-run: it overwrites its own outputs and never touches $HOME.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$HERE/packages"
DOT="$HERE/dotfiles"
DCONF="$HERE/dconf"
THEME="$HERE/zsh-theme"
mkdir -p "$PKG" "$DOT" "$DCONF" "$THEME"

say() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Category map. Package -> category. Anything not listed lands in
# "Uncategorized" so nothing is ever silently dropped.
# ---------------------------------------------------------------------------
declare -A CAT=(
  # Security · recon / scanning
  [nmap]="Security-Recon" [masscan]="Security-Recon" [arp-scan]="Security-Recon"
  [rustscan]="Security-Recon" [bettercap]="Security-Recon" [enum4linux]="Security-Recon"
  [whois]="Security-Recon" [bind]="Security-Recon" [mtr]="Security-Recon"
  [tcpdump]="Security-Recon" [ipcalc]="Security-Recon"
  # Security · web / directory fuzzing
  [ffuf]="Security-Web" [gobuster]="Security-Web" [dirsearch]="Security-Web"
  [nikto]="Security-Web" [wpscan]="Security-Web" [sqlmap]="Security-Web"
  [burpsuite]="Security-Web"
  # Security · password / hash cracking
  [hashcat]="Security-Cracking" [john]="Security-Cracking" [hydra]="Security-Cracking"
  [medusa]="Security-Cracking" [fcrackzip]="Security-Cracking"
  # Security · wireless
  [aircrack-ng]="Security-Wireless"
  # Security · exploitation / C2 / netcat
  [metasploit]="Security-Exploit" [exploitdb]="Security-Exploit"
  [openbsd-netcat]="Security-Exploit"
  # Security · reverse engineering / forensics / stego
  [binwalk]="Security-Forensics" [ghidra]="Security-Forensics" [radare2]="Security-Forensics"
  [wireshark-qt]="Security-Forensics" [ltrace]="Security-Forensics" [strace]="Security-Forensics"
  [steghide]="Security-Forensics" [stegseek]="Security-Forensics"
  [perl-image-exiftool]="Security-Forensics"
  # Security · anonymity
  [tor]="Security-Anon" [torsocks]="Security-Anon" [proxychains-ng]="Security-Anon"
  # Security · OSINT
  [sherlock]="Security-OSINT"
  # Terminal / CLI tooling
  [git]="Terminal-CLI" [github-cli]="Terminal-CLI" [lazygit]="Terminal-CLI"
  [jq]="Terminal-CLI" [yq]="Terminal-CLI" [httpie]="Terminal-CLI"
  [bat]="Terminal-CLI" [eza]="Terminal-CLI" [fd]="Terminal-CLI" [fzf]="Terminal-CLI"
  [ripgrep]="Terminal-CLI" [tealdeer]="Terminal-CLI" [tree]="Terminal-CLI"
  [htop]="Terminal-CLI" [btop]="Terminal-CLI" [wget]="Terminal-CLI" [lsof]="Terminal-CLI"
  [man-db]="Terminal-CLI" [7zip]="Terminal-CLI" [zip]="Terminal-CLI"
  [nano]="Terminal-CLI" [vim]="Terminal-CLI" [neovim]="Terminal-CLI"
  [zsh]="Terminal-CLI" [zsh-autosuggestions]="Terminal-CLI"
  [zsh-syntax-highlighting]="Terminal-CLI" [ghostty]="Terminal-CLI"
  [rofi]="Terminal-CLI" [wofi]="Terminal-CLI" [xclip]="Terminal-CLI"
  [wl-clipboard]="Terminal-CLI" [feh]="Terminal-CLI" [openssh]="Terminal-CLI"
  [smartmontools]="Terminal-CLI"
  # Development / containers / VMs / languages / editors
  [docker]="Dev-Tools" [docker-compose]="Dev-Tools" [lazydocker]="Dev-Tools"
  [qemu-full]="Dev-Tools" [libvirt]="Dev-Tools" [virt-manager]="Dev-Tools"
  [gcc]="Dev-Tools" [clang]="Dev-Tools" [cmake]="Dev-Tools" [make]="Dev-Tools"
  [debuginfod]="Dev-Tools" [postgresql]="Dev-Tools" [nodejs]="Dev-Tools" [npm]="Dev-Tools"
  [rustup]="Dev-Tools" [gopls]="Dev-Tools" [go]="Dev-Tools"
  [code]="Dev-Tools" [visual-studio-code-bin]="Dev-Tools" [zed]="Dev-Tools"
  [python-pip]="Dev-Tools" [python-pipx]="Dev-Tools" [python-requests]="Dev-Tools"
  [python-termcolor]="Dev-Tools" [python-evdev]="Dev-Tools" [cronie]="Dev-Tools"
  # AI / editors / desktop apps
  [obsidian]="Apps" [firefox]="Apps" [google-chrome]="Apps" [epiphany]="Apps"
  [libreoffice-still]="Apps" [claude-desktop-bin]="Apps" [opencode]="Apps"
  [qwen-code]="Apps" [openai-codex]="Apps" [variety]="Apps"
)

# GNOME desktop and system/driver buckets are matched by prefix below, so we
# don't have to enumerate every gnome-* and gvfs-* package by hand.
prefix_cat() {
  case "$1" in
    gnome-*|gdm|nautilus|gst-plugin-pipewire|gst-thumbnailers|grilo-plugins|rygel|\
    sushi|yelp|orca|loupe|papers|showtime|snapshot|decibels|baobab|simple-scan|\
    tecla|malcontent|xdg-utils|xdg-desktop-portal-gnome|xdg-user-dirs-gtk)
      echo "GNOME-Desktop" ;;
    gvfs*|pipewire*|wireplumber|libpulse|alsa-utils|bluez*|networkmanager|iwd|\
    network-manager-applet|dnsmasq|nftables|nss-mdns|ufw|openvpn|wireguard-tools|\
    linux|linux-firmware|intel-ucode|amd-ucode|sof-firmware|efibootmgr|grub|\
    base|base-devel|sudo|zram-generator|gnome-keyring|vulkan-*|xf86-video-*|\
    intel-media-driver|libva-intel-driver|ydotool|wtype|xdotool|xorg-xrandr|\
    blackarch-mirrorlist) echo "System-Base" ;;
    *) echo "" ;;
  esac
}

categorize() {
  local p="$1"
  if [[ -n "${CAT[$p]:-}" ]]; then echo "${CAT[$p]}"; return; fi
  local pc; pc="$(prefix_cat "$p")"
  if [[ -n "$pc" ]]; then echo "$pc"; return; fi
  echo "Uncategorized"
}

# Emit a package list grouped under "## Category" headers. Installer strips '#'.
write_categorized() {
  local outfile="$1"; shift
  local pkgs=("$@")
  declare -A bucket=()
  local p c
  for p in "${pkgs[@]}"; do
    [[ -n "$p" ]] || continue   # empty array expands to one empty arg
    c="$(categorize "$p")"
    bucket[$c]+="$p"$'\n'
  done
  {
    echo "# Generated by capture.sh on $(date -Iseconds)"
    echo "# Lines starting with # are comments; installer ignores them."
    echo
    for c in $(printf '%s\n' "${!bucket[@]}" | sort); do
      echo "## $c"
      printf '%s' "${bucket[$c]}" | sort
      echo
    done
  } > "$outfile"
}

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
say "Capturing pacman explicit packages (categorized)…"
# Split explicit packages: native repos vs BlackArch (needs repo bootstrap) vs foreign/AUR.
# The installer bootstraps yay-bin itself, and `yay` (blackarch) conflicts with
# it --- capturing either aborts the install transaction. *-debug packages are
# local build leftovers with no PKGBUILD to reinstall from. Drop both.
skip_pkg() {
  case "$1" in
    yay|yay-bin|yay-git|paru|paru-bin|*-debug) return 0 ;;
    *) return 1 ;;
  esac
}

mapfile -t EXPLICIT < <(pacman -Qqe)
native=(); blackarch=(); foreign=()
mapfile -t FOREIGN_SET < <(pacman -Qqm)
is_foreign() { local x; for x in "${FOREIGN_SET[@]}"; do [[ "$x" == "$1" ]] && return 0; done; return 1; }

for p in "${EXPLICIT[@]}"; do
  if skip_pkg "$p"; then
    warn "excluded from capture (bootstrapped or unbuildable): $p"
    continue
  fi
  if is_foreign "$p"; then
    foreign+=("$p"); continue
  fi
  repo="$(pacman -Si "$p" 2>/dev/null | awk -F': ' '/^Repository/{print $2; exit}')"
  if [[ "$repo" == "blackarch" ]]; then blackarch+=("$p"); else native+=("$p"); fi
done

write_categorized "$PKG/pacman-explicit.txt" ${native[@]+"${native[@]}"}
write_categorized "$PKG/blackarch.txt"       ${blackarch[@]+"${blackarch[@]}"}
write_categorized "$PKG/aur.txt"             ${foreign[@]+"${foreign[@]}"}

say "Capturing full package list (reference/verify only — NOT installed)…"
pacman -Qq  > "$PKG/pacman-all.txt"
# Flat explicit list, filtered the same way, so it can be diffed against the
# categorized files without the excluded packages showing up as drift.
printf '%s\n' ${native[@]+"${native[@]}"} ${blackarch[@]+"${blackarch[@]}"} \
               ${foreign[@]+"${foreign[@]}"} | sort > "$PKG/pacman-explicit-flat.txt"

# ---------------------------------------------------------------------------
# 2. Language-level globals — captured, install lines stay COMMENTED in installer
# ---------------------------------------------------------------------------
say "Capturing language-level global tools (reference)…"
{ npm ls -g --depth=0 2>/dev/null | tail -n +2 || true; } > "$PKG/npm-global.txt"
{ cargo install --list 2>/dev/null | grep -v '^ ' || true; } > "$PKG/cargo.txt"
{ ls "$HOME/go/bin" 2>/dev/null || true; } > "$PKG/go-bin.txt"
{ uv tool list 2>/dev/null || true; } > "$PKG/uv-tools.txt"

# ---------------------------------------------------------------------------
# 3. Dotfiles (curated) — secrets excluded by path, then verified by grep
# ---------------------------------------------------------------------------
say "Capturing curated dotfiles…"
DOTS=(
  .zshrc .zprofile .bashrc .bash_profile .gitconfig
  .config/git .config/nvim .config/ghostty .config/rofi
  .config/wofi .config/fish .config/gh .config/Code/User
)
# gh stores an oauth token in hosts.yml — copy config but drop that file.
GH_DENY=("hosts.yml")

# VS Code writes runtime state into .config/Code/User (History/, workspaceStorage/,
# globalStorage/ — hundreds of MB of caches, and where extensions park auth
# state). Keep only the hand-authored config; drop everything else.
CODE_USER_KEEP=(settings.json keybindings.json snippets)

rm -rf "$DOT"; mkdir -p "$DOT"
for rel in "${DOTS[@]}"; do
  src="$HOME/$rel"
  [[ -e "$src" ]] || { warn "skip (absent): $rel"; continue; }
  dst="$DOT/$rel"
  mkdir -p "$(dirname "$dst")"
  if [[ -d "$src" ]]; then
    cp -a "$src" "$(dirname "$dst")/"
  else
    cp -a "$src" "$dst"
  fi
done
# Strip gh credential file if present.
for f in "${GH_DENY[@]}"; do rm -f "$DOT/.config/gh/$f"; done

# Keep only hand-authored VS Code config; drop caches and extension state.
if [[ -d "$DOT/.config/Code/User" ]]; then
  while IFS= read -r -d '' entry; do
    name="$(basename "$entry")"
    keep=0
    for k in "${CODE_USER_KEEP[@]}"; do [[ "$name" == "$k" ]] && { keep=1; break; }; done
    (( keep )) || { warn "dropping VS Code runtime state: $name"; rm -rf "$entry"; }
  done < <(find "$DOT/.config/Code/User" -mindepth 1 -maxdepth 1 -print0)
fi

say "Verifying no secrets leaked into dotfiles…"
if grep -rIlE 'oauth_token|BEGIN [A-Z ]*PRIVATE KEY|api[_-]?key|secret[_-]?key|password[[:space:]]*=[[:space:]]*[^ ]' "$DOT" 2>/dev/null; then
  warn "Potential secret found in captured dotfiles (listed above)."
  warn "Inspect and remove before sharing. Aborting so nothing leaks."
  exit 1
fi

# ---------------------------------------------------------------------------
# 3b. zeroday zsh theme — the custom oh-my-zsh theme, its colour-bitmap font,
#     and the artwork/tools that generate them. Kept OUT of dotfiles/ because
#     those get symlinked: fontconfig only scans real directories, and
#     zeroday-build rewrites the artwork in place. install.sh copies these.
# ---------------------------------------------------------------------------
THEME_SRC="$HOME/.oh-my-zsh/custom/themes/zeroday.zsh-theme"
if [[ -f "$THEME_SRC" ]]; then
  say "Capturing zeroday zsh theme (theme, font, artwork)…"
  rm -rf "$THEME"; mkdir -p "$THEME/fonts" "$THEME/zeroday"
  cp -a "$THEME_SRC" "$THEME/zeroday.zsh-theme"
  if [[ -f "$HOME/.local/share/fonts/ZeroDayGlyphs.ttf" ]]; then
    cp -a "$HOME/.local/share/fonts/ZeroDayGlyphs.ttf" "$THEME/fonts/"
  else
    warn "zeroday: font missing; the prompt face will render as empty boxes"
  fi
  # venv/ and the regenerable intermediate (art.png) deliberately stay out.
  for f in source.png face.png sticker.png banner.ansi \
           render.py mkfont.py build.sh sticker.zsh; do
    [[ -f "$HOME/.local/share/zeroday/$f" ]] &&
      cp -a "$HOME/.local/share/zeroday/$f" "$THEME/zeroday/"
  done
  chmod 644 "$THEME"/zeroday/*.png 2>/dev/null || true
  chmod +x "$THEME/zeroday/build.sh" 2>/dev/null || true
else
  warn "skip (absent): zeroday zsh theme"
fi

# ---------------------------------------------------------------------------
# 4. GNOME settings via dconf — subtrees only (no monitor IDs / dead paths)
# ---------------------------------------------------------------------------
if command -v dconf >/dev/null; then
  say "Dumping GNOME dconf subtrees…"
  : > "$DCONF/gnome.ini"
  for path in /org/gnome/desktop/ /org/gnome/shell/keybindings/ /org/gnome/settings-daemon/; do
    echo "### DCONF-PATH $path" >> "$DCONF/gnome.ini"
    dconf dump "$path" >> "$DCONF/gnome.ini" 2>/dev/null || true
    echo >> "$DCONF/gnome.ini"
  done
fi

# ---------------------------------------------------------------------------
# 5. Generate the self-contained install.sh
#
# install.sh = install-template.sh with every captured file spliced in as a
# quoted heredoc, so a single file reproduces the machine with no repo present.
# ---------------------------------------------------------------------------
TEMPLATE="$HERE/install-template.sh"
OUT="$HERE/install.sh"
DELIM='__ARCH_SETUP_PAYLOAD_EOF__'

if [[ ! -f "$TEMPLATE" ]]; then
  warn "missing $TEMPLATE — cannot generate install.sh"
  exit 1
fi
if ! grep -qx '#__PAYLOAD__' "$TEMPLATE"; then
  warn "$TEMPLATE has no '#__PAYLOAD__' marker — cannot generate install.sh"
  exit 1
fi

say "Generating self-contained install.sh…"
# zsh-theme/ joins the payload so the standalone installer stays truly
# self-contained; it is optional, so a repo without it still generates.
PAYLOAD_DIRS=("$HERE/packages" "$HERE/dotfiles" "$HERE/dconf")
[[ -d "$HERE/zsh-theme" ]] && PAYLOAD_DIRS+=("$HERE/zsh-theme")
nfiles=0
{
  sed '/^#__PAYLOAD__$/,$d' "$TEMPLATE"

  echo "# --- BEGIN EMBEDDED PAYLOAD — generated by capture.sh, do not edit ---"
  cat <<'PAYLOAD_HELPERS'
_dir() { mkdir -p "$ROOT/$1"; }
# _file <relpath> <strip-trailing-newline> [octal-mode]  — content on stdin.
# A heredoc always ends in a newline; files captured without one are trimmed
# back so the unpacked copy is byte-identical to the original.
_file() {
  local rel="$1" strip="${2:-0}" mode="${3:-}"
  mkdir -p "$ROOT/$(dirname "$rel")"
  cat > "$ROOT/$rel"
  if (( strip )); then truncate -s -1 "$ROOT/$rel"; fi
  [[ -n "$mode" ]] && chmod "$mode" "$ROOT/$rel"
  return 0
}
# _b64file <relpath> [octal-mode]  — base64 content on stdin.
# A quoted heredoc can only carry text, so binary payload (the theme's PNGs and
# its TTF) travels base64-encoded. The encoding alphabet cannot contain the
# heredoc delimiter, so no collision check is needed on this path.
_b64file() {
  local rel="$1" mode="${2:-}"
  mkdir -p "$ROOT/$(dirname "$rel")"
  base64 -d > "$ROOT/$rel"
  [[ -n "$mode" ]] && chmod "$mode" "$ROOT/$rel"
  return 0
}
unpack_payload() {
PAYLOAD_HELPERS

  # Empty directories carry no file to imply them (VS Code's snippets/).
  while IFS= read -r -d '' d; do
    printf '  _dir %q\n' "${d#$HERE/}"
  done < <(find "${PAYLOAD_DIRS[@]}" -type d -empty -print0 | sort -z)

  while IFS= read -r -d '' f; do
    rel="${f#$HERE/}"
    if grep -qxF "$DELIM" "$f"; then
      warn "heredoc delimiter collides with content of $rel — aborting"
      exit 1
    fi
    # Only a non-default mode is worth emitting (build.sh must stay +x).
    modearg=""
    [[ "$(stat -c '%a' "$f")" != "644" ]] && modearg=" $(stat -c '%a' "$f")"
    if [[ -s "$f" ]] && ! grep -qI . "$f" 2>/dev/null; then
      printf '  _b64file %q%s <<%s\n' "$rel" "$modearg" "'$DELIM'"
      base64 "$f"
      printf '%s\n' "$DELIM"
      nfiles=$(( nfiles + 1 ))
      continue
    fi
    strip=0
    if [[ -s "$f" ]] && [[ "$(tail -c1 "$f" | od -An -tx1 | tr -d ' \n')" != "0a" ]]; then
      strip=1
    fi
    printf '  _file %q %d%s <<%s\n' "$rel" "$strip" "$modearg" "'$DELIM'"
    cat "$f"
    if (( strip )); then echo; fi   # close the heredoc on its own line
    printf '%s\n' "$DELIM"
    nfiles=$(( nfiles + 1 ))
  done < <(find "${PAYLOAD_DIRS[@]}" -type f -print0 | sort -z)

  echo "}"
  echo "# --- END EMBEDDED PAYLOAD ---"

  sed '1,/^#__PAYLOAD__$/d' "$TEMPLATE"
} > "$OUT"
chmod +x "$OUT"

if ! bash -n "$OUT"; then
  warn "generated install.sh does not parse — refusing to ship it"
  exit 1
fi
say "install.sh generated: $(wc -c < "$OUT") bytes, $(find "${PAYLOAD_DIRS[@]}" -type f | wc -l) files embedded"

say "Capture complete. Review ./packages, ./dotfiles, ./dconf and install.sh before committing."
