
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/bashrc.pre.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bashrc.pre.bash"

#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '



# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/bashrc.post.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bashrc.post.bash"
