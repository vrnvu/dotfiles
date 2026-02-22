# PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="/Users/arnau/Documents/dev/zig:$PATH"
export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"

# Editor
export EDITOR=nvim
alias vi=nvim

# fzf
autoload -Uz compinit
compinit
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Aliases
alias bat="bat --style=plain"
alias dockerm='docker stop "$1" && docker rm "$1"'
alias dev='cd ~/Documents/dev'
alias dotfiles='cd ~/dotfiles'
alias home='cd ~'
alias ..='cd ..'
alias -- -='cd -'

# Enable auto cd
setopt AUTO_CD

# Functions
brew-sync() {
  brew update &&
  brew bundle install --cleanup --file=~/.Brewfile &&
  brew upgrade
}

t() {
  pushd "$(mktemp -d /tmp/$1.XXXX)"
}

# Minimal prompt
autoload -Uz colors && colors
setopt prompt_subst
PROMPT='%F{cyan}➜%f  %F{yellow}%1~%f %(?.%F{green}.%F{red})%#%f '
