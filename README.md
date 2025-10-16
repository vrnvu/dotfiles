## Dotfiles 

- Uses Homebrew, Brewfile, and GNU Stow.
- Symlinks only `zsh`, `git`, and `ssh` into `$HOME`.
- Editor configs (VSCode/Cursor) are kept in `dotfiles/` but not stowed.

### Quick start
```bash
git clone https://github.com/vrnvu/dotfiles "$HOME/dotfiles"
"$HOME/dotfiles/scripts/bootstrap.sh"
```

### Notes
- The script is idempotent.
- `ssh` is stowed with `--no-folding` so `~/.ssh` remains a real directory.
- VSCode/Cursor `settings.json` and `keybindings.json` are stored here for reference; they are not symlinked by the script. VSCode extensions are installed by the Brewfile and require the `code` CLI to be available (installed via VSCode Command Palette or symlinked automatically by bootstrap).

