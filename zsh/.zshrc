# add Zig
export PATH=/Users/arnau/Documents/dev/zig:$PATH

# add Code
export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# oh my zsh 
ZSH_THEME="robbyrussell"
plugins=(git fzf docker-compose)
source $ZSH/oh-my-zsh.sh

# set editor
export EDITOR=nvim


# aliases and funcs
alias vi=nvim
alias bat="bat --style=plain"
alias dockerm='docker stop "$1" && docker rm "$1"'
alias dev='cd ~/Documents/dev'
alias log='cd ~/Documents/dev/log'
alias home='cd ~'

function brew-sync() {
  brew update &&
  brew bundle install --cleanup --file=~/.Brewfile &&
  brew upgrade
}

# temporary folder
function t {
  pushd $(mktemp -d /tmp/$1.XXXX)
}
