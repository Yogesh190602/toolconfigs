# zeroday-sticker — draw the real artwork inline using the Kitty graphics
# protocol (supported by Ghostty >= 1.0 and kitty). Falls back to the ASCII
# banner anywhere else.
zeroday-sticker() {
  local img="$HOME/.local/share/zeroday/sticker.png"
  local rows=${1:-14}

  # Terminals known to speak the Kitty graphics protocol.
  case "$TERM$KITTY_WINDOW_ID$GHOSTTY_RESOURCES_DIR" in
    *ghostty*|*kitty*) ;;
    *) zeroday; return ;;
  esac
  [[ -r $img ]] || { zeroday; return }

  local b64 esc=$'\e' bs=$'\\'
  b64=$(base64 -w0 "$img") || { zeroday; return }

  # a=T transmit+display, f=100 PNG, t=d direct (payload inline), m=1 more chunks.
  # Only `r` is given so the terminal derives columns from the aspect ratio.
  local -i n=${#b64} i=1 chunk=4096
  local first=1
  while (( i <= n )); do
    local part=${b64[i,i+chunk-1]}
    local more=1
    (( i + chunk > n )) && more=0
    if (( first )); then
      printf '%s_Ga=T,f=100,t=d,r=%d,m=%d;%s%s%s' "$esc" "$rows" "$more" "$part" "$esc" "$bs"
      first=0
    else
      printf '%s_Gm=%d;%s%s%s' "$esc" "$more" "$part" "$esc" "$bs"
    fi
    (( i += chunk ))
  done
  printf '\n'
}
