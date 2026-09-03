
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/bash_profile.pre.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bash_profile.pre.bash"

#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc



# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/bash_profile.post.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bash_profile.post.bash"
