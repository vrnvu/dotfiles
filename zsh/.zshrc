# add Zig
export PATH=/Users/arnau/Documents/dev/zig:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# oh my zsh 
ZSH_THEME="robbyrussell"
plugins=(git fzf docker-compose)
source $ZSH/oh-my-zsh.sh


# aliases and funcs
alias bat="bat --style=plain"
alias dockerm='docker stop "$1" && docker rm "$1"'
alias dev='cd ~/Documents/dev'
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

# func to convert numbers quickly
# Convert Decimal to Hexadecimal
to_hex_from_dec() {
    printf "%x\n" "$1"
}

# Convert Decimal to Binary
to_bin_from_dec() {
    echo "obase=2; $1" | bc
}

# Convert Hexadecimal to Decimal
to_dec_from_hex() {
    printf "%d\n" "$((16#$1))"
}

# Convert Binary to Decimal
to_dec_from_bin() {
    echo "$((2#$1))"
}

# Convert Hexadecimal to Binary
to_bin_from_hex() {
    echo "obase=2; ibase=16; $1" | bc
}

# Convert Binary to Hexadecimal
to_hex_from_bin() {
    echo "obase=16; ibase=2; $1" | bc
}
