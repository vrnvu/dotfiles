#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: bootstrap failed"; exit 1' ERR

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly DEFAULT_DOTFILES_DIR="$REPO_ROOT"
readonly DEFAULT_BREWFILE_LINK="$HOME/.Brewfile"

readonly -a STOW_PACKAGES_NORMAL=( zsh git vscode cursor )
# ssh uses --no-folding to prevent stow from replacing ~/.ssh with a symlink.
# This keeps ~/.ssh a real directory so private keys remain outside the repo.
readonly -a STOW_PACKAGES_NOFOLD=( ssh )

function has() { command -v "$1" >/dev/null 2>&1; }
function is_macos() { [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]]; }
function require_cmd() { has "$1" || { echo "missing: $1"; exit 1; }; }

# Sanity check: verify a non-macOS tool from the Brewfile was installed.
# We pick `bat` because macOS does not ship it by default.
function check_bat() { command -v bat >/dev/null 2>&1 || { echo "expected bat missing after bundle"; exit 1; }; }

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

function setup_git() {
  if ! has git; then
    brew install git
  fi
  git --version >/dev/null
}

function setup_brewfile() {
  local dotfiles_dir brewfile_src
  dotfiles_dir="$DEFAULT_DOTFILES_DIR"
  brewfile_src="${dotfiles_dir}/Brewfile"
  [[ -f "$brewfile_src" ]] || { echo "Brewfile missing at $brewfile_src"; exit 1; }
  ln -sf "$brewfile_src" "$DEFAULT_BREWFILE_LINK"
}

function setup_brew_sync() {
  brew update
  brew bundle install --cleanup --file="$DEFAULT_BREWFILE_LINK"
  brew upgrade
  check_bat
}

function setup_dotfiles() {
  has stow || brew install stow
  local dotfiles_dir
  dotfiles_dir="$DEFAULT_DOTFILES_DIR"
  cd "$dotfiles_dir"

  # Ensure SSH dir exists and has correct perms; prevents dir symlink folding
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # Restow general packages
  stow -Rv -t "$HOME" "${STOW_PACKAGES_NORMAL[@]}"

  # Stow ssh without directory folding so ~/.ssh remains a real directory
  stow -Rv -t "$HOME" --no-folding "${STOW_PACKAGES_NOFOLD[@]}"

  [[ -f "$HOME/.zshrc" && -f "$HOME/.gitconfig" ]] || { echo "core dotfiles missing after stow"; exit 1; }
  [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config"
  zsh -lc 'true' || echo "warning: zsh returned non-zero; check .zshrc"
}

function setup_ssh() {
  # Generate key if missing; print pub for GitHub
  local email
  email="$(git config --global --get user.email || true)"
  [[ -n "$email" ]] || { echo "error: git user.email is not set. Configure it in ~/.gitconfig before running bootstrap."; exit 1; }
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
  [[ -n "$name" ]] || { echo "error: git user.name is not set. Configure it in ~/.gitconfig before running bootstrap."; exit 1; }
  [[ -n "$email" ]] || { echo "error: git user.email is not set. Configure it in ~/.gitconfig before running bootstrap."; exit 1; }
  git config --global core.excludesfile >/dev/null 2>&1 || git config --global core.excludesfile "$HOME/.gitignore_global"
}

function check_doctor() { brew doctor || true; }
function check_brew_bundle() { brew bundle check --file="$DEFAULT_BREWFILE_LINK" || true; }
function check_code() { command -v code >/dev/null 2>&1 && code --version >/dev/null || true; }
function check_docker() { command -v docker >/dev/null 2>&1 && docker --version >/dev/null || true; }

function main() {
  is_macos || { echo "macOS required"; exit 1; }
  [[ -d "$DEFAULT_DOTFILES_DIR" ]] || { echo "missing dotfiles dir: $DEFAULT_DOTFILES_DIR"; exit 1; }

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
