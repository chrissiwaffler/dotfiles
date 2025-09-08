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

# Syncthing usage

for syncing work between machines (e.g., also secrets) when git would be too much overhead

- have syncthing installed on macbook and turned on for the nixos machine (`syncthing.enable = true; `)
- ideally, have desktop machine and local macbook connected via tailscale
- open syncthing webui from desktop: `ssh -L 8383:localhost:8384 chrissi@desktop`
- open syncthing webui from macbook: `syncthing`
- copy the device id from the one and add it to the other; then accept the request
- then select the folder that needs to be synced, add, share it for the other device and accept the request
- then also configure files that need to be ignored
