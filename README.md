## Dotfiles 

- Uses Homebrew, Brewfile, and GNU Stow.
- Symlinks `zsh`, `git`, `ssh`, `vscode`, `cursor` into `$HOME`.

### Quick start
```bash
git clone https://github.com/vrnvu/dotfiles "$HOME/dotfiles"
"$HOME/dotfiles/scripts/bootstrap.sh"
```

### Notes
- The script is idempotent.
- Only `settings.json` and `keybindings.json` for Cursor/VSCode are tracked; extensions install via Brew.

