#!/usr/bin/env bash
# install.sh — reproduce this Arch setup on a NEW machine.
# Run as your normal user (NOT root). Uses sudo per-command; makepkg refuses root.
#
#   ./install.sh              # do it
#   ./install.sh --dry-run    # print every action, change nothing
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$HERE/packages"
DOT="$HERE/dotfiles"
DCONF="$HERE/dconf"

DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

say()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
run()  { if (( DRY )); then printf '\033[2m[dry] %s\033[0m\n' "$*"; else eval "$*"; fi; }

[[ $EUID -eq 0 ]] && { warn "Do not run as root. Run as your user; sudo is used where needed."; exit 1; }
command -v pacman >/dev/null || { warn "Not an Arch system (no pacman)."; exit 1; }

# Read a categorized package file: drop blank lines and #-comments.
read_pkgs() { grep -vE '^\s*#' "$1" 2>/dev/null | grep -vE '^\s*$' || true; }

# ---------------------------------------------------------------------------
# 1. Native pacman packages
# ---------------------------------------------------------------------------
say "Updating package databases…"
run "sudo pacman -Syu --noconfirm"

mapfile -t NATIVE < <(read_pkgs "$PKG/pacman-explicit.txt")
if (( ${#NATIVE[@]} )); then
  say "Installing ${#NATIVE[@]} native packages…"
  run "sudo pacman -S --needed --noconfirm ${NATIVE[*]}"
fi

# ---------------------------------------------------------------------------
# 2. yay (AUR helper) — bootstrap, since yay can't install itself
# ---------------------------------------------------------------------------
if ! command -v yay >/dev/null; then
  say "Bootstrapping yay from AUR…"
  run "sudo pacman -S --needed --noconfirm base-devel git"
  run "tmp=\$(mktemp -d) && git clone https://aur.archlinux.org/yay-bin.git \"\$tmp/yay-bin\" && (cd \"\$tmp/yay-bin\" && makepkg -si --noconfirm)"
fi

# ---------------------------------------------------------------------------
# 3. BlackArch repo + its packages (only if we captured any)
# ---------------------------------------------------------------------------
mapfile -t BA < <(read_pkgs "$PKG/blackarch.txt")
if (( ${#BA[@]} )); then
  if ! pacman -Sl blackarch >/dev/null 2>&1; then
    say "Adding BlackArch repository (strap.sh)…"
    run "tmp=\$(mktemp -d) && curl -fsSL https://blackarch.org/strap.sh -o \"\$tmp/strap.sh\" && echo 'Review \$tmp/strap.sh before trusting it.' && chmod +x \"\$tmp/strap.sh\" && sudo \"\$tmp/strap.sh\""
    run "sudo pacman -Syu --noconfirm"
  fi
  say "Installing ${#BA[@]} BlackArch packages…"
  run "sudo pacman -S --needed --noconfirm ${BA[*]}"
fi

# ---------------------------------------------------------------------------
# 4. AUR / foreign packages (best-effort — some captured ones are local builds)
# ---------------------------------------------------------------------------
mapfile -t AUR < <(read_pkgs "$PKG/aur.txt")
if (( ${#AUR[@]} )); then
  say "Installing AUR packages (best-effort)…"
  for p in "${AUR[@]}"; do
    run "yay -S --needed --noconfirm '$p' || echo \"  skip: $p (no AUR PKGBUILD / local build)\""
  done
fi

# ---------------------------------------------------------------------------
# 5. oh-my-zsh (reinstalled from upstream, not copied)
# ---------------------------------------------------------------------------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  say "Installing oh-my-zsh…"
  run "RUNZSH=no CHSH=no sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
fi

# ---------------------------------------------------------------------------
# 6. Dotfiles — symlink into $HOME, backing up anything real that's in the way
# ---------------------------------------------------------------------------
STAMP="$(date +%s)"
BACKUP="$HOME/.pre-setup-backup-$STAMP"
link_one() {
  local src="$1" tgt="$2"
  if [[ -L "$tgt" && "$(readlink -f "$tgt")" == "$(readlink -f "$src")" ]]; then
    return  # already correct
  fi
  if [[ -e "$tgt" || -L "$tgt" ]]; then
    run "mkdir -p \"$BACKUP/\$(dirname '${tgt#$HOME/}')\""
    run "mv \"$tgt\" \"$BACKUP/${tgt#$HOME/}\""
  fi
  run "mkdir -p \"\$(dirname '$tgt')\""
  run "ln -s \"$src\" \"$tgt\""
}

if [[ -d "$DOT" ]]; then
  say "Linking dotfiles (backups -> $BACKUP)…"
  # Link each top-level entry and each item inside .config individually, so we
  # never blow away the whole ~/.config directory.
  while IFS= read -r -d '' f; do
    rel="${f#$DOT/}"
    link_one "$f" "$HOME/$rel"
  done < <(find "$DOT" -mindepth 1 -maxdepth 1 ! -name .config -print0)
  if [[ -d "$DOT/.config" ]]; then
    while IFS= read -r -d '' f; do
      name="$(basename "$f")"
      # VS Code owns .config/Code and writes cache/state there; link only the
      # User/ subdir so its runtime junk never lands in the repo.
      if [[ "$name" == "Code" && -d "$f/User" ]]; then
        link_one "$f/User" "$HOME/.config/Code/User"
      else
        link_one "$f" "$HOME/.config/$name"
      fi
    done < <(find "$DOT/.config" -mindepth 1 -maxdepth 1 -print0)
  fi
fi

# ---------------------------------------------------------------------------
# 7. GNOME dconf restore
# ---------------------------------------------------------------------------
if [[ -f "$DCONF/gnome.ini" ]] && command -v dconf >/dev/null; then
  say "Restoring GNOME dconf settings…"
  path=""; buf=""
  flush() { [[ -n "$path" && -n "$buf" ]] && { if (( DRY )); then printf '\033[2m[dry] dconf load %s\033[0m\n' "$path"; else printf '%s' "$buf" | dconf load "$path"; fi; }; }
  while IFS= read -r line; do
    if [[ "$line" == "### DCONF-PATH "* ]]; then
      flush; path="${line#### DCONF-PATH }"; buf=""
    else
      buf+="$line"$'\n'
    fi
  done < "$DCONF/gnome.ini"
  flush
fi

# ---------------------------------------------------------------------------
# 8. Enable the services this box relies on
# ---------------------------------------------------------------------------
say "Enabling common services (best-effort)…"
for svc in gdm NetworkManager docker cronie; do
  run "sudo systemctl enable $svc.service 2>/dev/null || true"
done

# ---------------------------------------------------------------------------
# 9. Manual follow-ups
# ---------------------------------------------------------------------------
cat <<'EOF'

============================================================
 DONE. Manual steps the script deliberately did NOT do:
============================================================
  - Secrets & keys (excluded on purpose):
      ~/.ssh, ~/.gnupg, ~/.aws         -> copy from a secure backup
      gh auth:  run  `gh auth login`
      git:      credential helper is gh; no token stored
  - Language globals (captured, not installed). Review then run:
      packages/npm-global.txt, cargo.txt, go-bin.txt, uv-tools.txt
  - Change your login shell to zsh:   chsh -s /usr/bin/zsh
  - Docker group (log out/in after):  sudo usermod -aG docker "$USER"
  - Reboot to pick up GNOME/dconf and services.
============================================================
EOF
