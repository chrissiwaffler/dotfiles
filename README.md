# personal dotfiles

```bash
nix flake check --all-systems
```

# macos usage

to sync the configuration files in `config`, install stow: `brew install stow`
and sync then:

```bash
# setup (run once on each machine)
cd ~/dotfiles
stow --target ~/.config config

# updates (after git pull)
cd ~/dotfiles
stow --restow --target ~/.config config
```
