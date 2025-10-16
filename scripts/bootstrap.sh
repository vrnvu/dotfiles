#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
trap 'printf "error: %s\n" "bootstrap failed on: $BASH_COMMAND" >&2; exit 1' ERR

# Dirs and files
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly DEFAULT_DOTFILES_DIR="$REPO_ROOT"
readonly DEFAULT_BREWFILE_LINK="$HOME/.Brewfile"

# Stow helpers (KISS)
function stow_zsh() { stow -Rv --dir "$DEFAULT_DOTFILES_DIR" --target "$HOME" zsh; }
function stow_git() { stow -Rv --dir "$DEFAULT_DOTFILES_DIR" --target "$HOME" git; }
# Keep ~/.ssh as a real directory; do not fold to a symlink
function stow_ssh() { stow -Rv --no-folding --dir "$DEFAULT_DOTFILES_DIR" --target "$HOME" ssh; }

function has() { command -v "$1" >/dev/null 2>&1; }
function is_macos() { [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]; }
function die() { printf '%s\n' "$*" >&2; exit 1; }
function require_cmd() { has "$1" || die "missing: $1"; }

# Sanity check: verify a non-macOS tool from the Brewfile was installed.
# We pick `bat` because macOS does not ship it by default.
function check_bat() { command -v bat >/dev/null 2>&1 || { echo "expected bat missing after bundle"; exit 1; }; }
function check_doctor() { brew doctor || true; }
function check_brew_bundle() { brew bundle check --file="$DEFAULT_BREWFILE_LINK" || true; }
function check_code() { command -v code >/dev/null 2>&1 && code --version >/dev/null || true; }
function check_docker() { command -v docker >/dev/null 2>&1 && docker --version >/dev/null || true; }

function setup_xcode() {
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Installing Xcode Command Line Tools (may open GUI)..."
    xcode-select --install || true
    for _ in {1..30}; do xcode-select -p >/dev/null 2>&1 && break; sleep 2; done
  fi
}

function setup_brew() {
  if ! has brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  # shellenv for current shell only; do not write to ~/.zshrc
  local brew_prefix; brew_prefix="$(/usr/bin/env brew --prefix)"
  eval "$("${brew_prefix}/bin/brew" shellenv)"
  export HOMEBREW_NO_ENV_HINTS=1
  brew --version >/dev/null
}

# Make sure VSCode CLI is available for Brewfile extensions
function ensure_code_cli() {
  command -v code >/dev/null 2>&1 && return 0
  local app_bin="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  local brew_bin
  brew_bin="$(/usr/bin/env brew --prefix)/bin/code"
  if [[ -x "$app_bin" ]]; then
    ln -sf "$app_bin" "$brew_bin"
  fi
}

function setup_git() {
  if ! has git; then
    brew install git
  fi
  git --version >/dev/null
}

function setup_brewfile() {
  local brewfile_src; brewfile_src="${DEFAULT_DOTFILES_DIR}/Brewfile"
  [[ -f "$brewfile_src" ]] || die "Brewfile missing at $brewfile_src"
  ln -sf "$brewfile_src" "$DEFAULT_BREWFILE_LINK"
}

function setup_brew_sync() {
  brew update
  ensure_code_cli
  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --cleanup --file="$DEFAULT_BREWFILE_LINK" || {
    echo "warning: brew bundle install encountered errors; continuing"
  }
  brew upgrade
  check_bat
}

function setup_dotfiles() {
  has stow || brew install stow
  # Ensure SSH dir exists and has correct perms; prevents dir symlink folding
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  stow_zsh
  stow_git
  stow_ssh

  [[ -f "$HOME/.zshrc" && -f "$HOME/.gitconfig" ]] || die "core dotfiles missing after stow"
  [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
  zsh -lc 'true' || echo "warning: zsh returned non-zero; check .zshrc"
}

function setup_ssh() {
  # Generate key if missing; print pub for GitHub
  local email; email="$(git config --global --get user.email || true)"
  [[ -n "$email" ]] || die "error: git user.email is not set. Configure it in ~/.gitconfig before running bootstrap."
  if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
    umask 077
    ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519" -N ""
    ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" || true
  fi
  [[ -f "$HOME/.ssh/id_ed25519.pub" ]] && echo "SSH pubkey: $HOME/.ssh/id_ed25519.pub"
}

function setup_gitconfig() {
  local name email
  name="$(git config --global --get user.name || true)"
  email="$(git config --global --get user.email || true)"
  [[ -n "$name" ]] || die "error: git user.name is not set. Configure it in ~/.gitconfig before running bootstrap."
  [[ -n "$email" ]] || die "error: git user.email is not set. Configure it in ~/.gitconfig before running bootstrap."
  git config --global core.excludesfile >/dev/null 2>&1 || git config --global core.excludesfile "$HOME/.gitignore_global"
}

function main() {
  is_macos || die "macOS required"
  [[ -d "$DEFAULT_DOTFILES_DIR" ]] || die "missing dotfiles dir: $DEFAULT_DOTFILES_DIR"

  setup_xcode
  setup_brew
  setup_git
  setup_brewfile
  setup_brew_sync
  setup_dotfiles
  setup_ssh
  setup_gitconfig
  check_doctor
  check_brew_bundle
  check_code
  check_docker

  echo "done"
}

main "$@"
