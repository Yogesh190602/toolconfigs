#!/usr/bin/env bash
# zeroday-build — turn any image into the theme's artwork.
#
#   zeroday-build <image> [rows] [crop]
#
#     rows   height of the banner art in terminal rows (default 13)
#     crop   optional ImageMagick geometry, e.g. 408x242+0+128, applied before
#            rendering. Use it to cut baked-in lettering out of the art: text
#            shrunk to a few rows turns to mush, and the theme redraws the
#            tagline as real text underneath anyway.
#
# Writes to ~/.local/share/zeroday/:
#   sticker.png   transparent + trimmed, full image  (used by `zeroday-sticker`)
#   banner.ansi   truecolor half-block art, cached   (used by `zeroday`)
set -euo pipefail
dir="$HOME/.local/share/zeroday"
src=${1:?usage: zeroday-build <image> [rows] [crop]}
rows=${2:-13}
crop=${3:-}
[[ -r $src ]] || { echo "zeroday-build: cannot read $src" >&2; exit 1; }

flatten=(-alpha set -fuzz 15% -fill none -draw 'alpha 1,1 floodfill')

# Full image -> sticker.png, for the real-pixel Kitty-protocol version.
magick "$src" "${flatten[@]}" -trim +repage "PNG32:$dir/sticker.png"

# Optionally cropped -> art.png -> cached half-block banner.
if [[ -n $crop ]]; then
  magick "$src" -crop "$crop" +repage "${flatten[@]}" -trim +repage "PNG32:$dir/art.png"
else
  cp "$dir/sticker.png" "$dir/art.png"
fi
python3 "$dir/render.py" "$dir/art.png" "$rows" > "$dir/banner.ansi"

printf 'zeroday-build: %s -> sticker %s, banner %s rows%s\n' \
  "$(basename "$src")" "$(identify -format '%wx%h' "$dir/sticker.png")" "$rows" \
  "${crop:+ (crop $crop)}"
