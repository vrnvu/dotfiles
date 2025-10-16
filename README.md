## Dotfiles 

- Uses Homebrew, Brewfile, and GNU Stow.
- Symlinks `zsh`, `git`, `ssh`, `nvim`, `vscode`, `cursor` into `$HOME`.

### Quick start
```bash
git clone https://github.com/vrnvu/dotfiles "$HOME/dotfiles"
"$HOME/dotfiles/scripts/bootstrap.sh" -n "adt" -e "hi@adt.com"
```

### Notes
- Set `DOTFILES_DIR` to use a custom location.
- Brew sync: links `Brewfile` to `~/.Brewfile`, runs `brew bundle`, then upgrades and cleans up.
- The script is safe to re-run.
- Editor configs: only `settings.json` and `keybindings.json` are tracked (Cursor/VSCode). Extensions install via Brew.

 

