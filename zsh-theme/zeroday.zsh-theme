# zeroday.zsh-theme — "just another ZERO DAY"
# Palette lifted from the artwork: amber-to-orange cat, red accent, slate laptop.
#
#   AMBER  #FFC933   cat highlight        RED   #F04E23   the "ZERO" accent
#   ORANGE #F59A1E   cat body             SLATE #8A929B   laptop shell
#   DEEP   #E8720C   cat shadow           BONE  #C9CDD2   skull

ZERODAY_AMBER='#FFC933'
ZERODAY_ORANGE='#F59A1E'
ZERODAY_DEEP='#E8720C'
ZERODAY_RED='#F04E23'
ZERODAY_SLATE='#8A929B'
ZERODAY_BONE='#C9CDD2'

# Prompt face. Override in ~/.zshrc to taste, e.g. ZERODAY_FACE='(=ᐛ=)'
[[ -z $ZERODAY_FACE ]] && ZERODAY_FACE='😾'

PROMPT='%F{'$ZERODAY_AMBER'}${ZERODAY_FACE}%f %F{'$ZERODAY_ORANGE'}%c%f $(git_prompt_info)%F{'$ZERODAY_DEEP'}▸%f '

# Non-zero exit shows a skull on the right, the way the laptop does in the art.
RPROMPT='%(?..%F{'$ZERODAY_RED'}💀 %?%f)'

ZSH_THEME_GIT_PROMPT_PREFIX="%F{$ZERODAY_SLATE}[%f%F{$ZERODAY_AMBER}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f "
ZSH_THEME_GIT_PROMPT_DIRTY="%F{$ZERODAY_SLATE}]%f %F{$ZERODAY_RED}💀%f"
ZSH_THEME_GIT_PROMPT_CLEAN="%F{$ZERODAY_SLATE}]%f"

# Banner: half-block render of the artwork, plus the tagline as real text so
# it stays legible at terminal sizes. Regenerate from any image with
# `zeroday-build <file.png>`. Not run automatically — call `zeroday` yourself.
zeroday() {
  local art="$HOME/.local/share/zeroday/banner.ansi"
  print ""
  if [[ -r $art ]]; then
    cat "$art"
  else
    print -rP "   %F{$ZERODAY_ORANGE}( %F{$ZERODAY_AMBER}\u25e3_\u25e2%F{$ZERODAY_ORANGE} )%f"
  fi
  print -rP "   %F{$ZERODAY_BONE}JUST ANOTHER%f %F{$ZERODAY_RED}ZERO%f %F{$ZERODAY_BONE}DAY%f"
  print ""
}

# Real-artwork sticker (Kitty graphics protocol), if it's been generated.
[[ -r $HOME/.local/share/zeroday/sticker.zsh ]] && source $HOME/.local/share/zeroday/sticker.zsh
