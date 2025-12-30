{
  config,
  pkgs,
  lib,
  ...
}: {
  # ZSH Configuration
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Oh My Zsh
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [
        "git"
        "docker"
        "kubectl"
        "python"
        "pip"
        "sudo"
        "z"
        "fzf"
        "tmux"
      ];
    };

    # History
    history = {
      size = 100000;
      save = 100000;
      path = "${config.xdg.dataHome}/zsh/history";
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    # Aliases
    shellAliases = {
      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # ls replacements
      ls = "eza --icons --group-directories-first";
      ll = "eza -la --icons --group-directories-first";
      la = "eza -a --icons --group-directories-first";
      lt = "eza --tree --icons";

      # Modern replacements
      cat = "bat";
      grep = "rg";
      find = "fd";
      ps = "procs";
      top = "btop";
      du = "dust";

      # Quick edits
      dots = "cd ~/dotfiles && nvim";
      nixconf = "cd /etc/nixos && nvim";

      # Clipboard (Linux)
      pbcopy = lib.mkIf pkgs.stdenv.isLinux "xclip -selection clipboard";
      pbpaste = lib.mkIf pkgs.stdenv.isLinux "xclip -selection clipboard -o";

      # Safety
      rm = "rm -i";
      cp = "cp -i";
      mv = "mv -i";
    };

    initContent = ''
       # Add OpenMPI to LD_LIBRARY_PATH if available
       ${lib.optionalString (pkgs ? openmpi) ''export LD_LIBRARY_PATH="${pkgs.openmpi}/lib:$LD_LIBRARY_PATH"''}

       # Better key bindings
       bindkey '^[[A' history-substring-search-up
       bindkey '^[[B' history-substring-search-down
       bindkey '^[[1;5C' forward-word
       bindkey '^[[1;5D' backward-word

       # FZF configuration
       export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
       export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
       export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

      # Auto-cd into directory by typing its name
      setopt autocd

      # Better globbing
      setopt extended_glob
      setopt glob_dots

      # No beep
      unsetopt beep

      # Quick directory switching
      eval "$(zoxide init zsh)"

      # Source local config if exists
      [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
    '';
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = lib.concatStrings [
        "$username"
        "$hostname"
        "$directory"
        "$git_branch"
        "$git_status"
        "$python"
        "$nodejs"
        "$rust"
        "$golang"
        "$nix_shell"
        "$docker_context"
        "$kubernetes"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = false;
      };

      git_branch = {
        symbol = " ";
      };

      git_status = {
        ahead = "⇡$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        behind = "⇣$count";
      };

      python = {
        symbol = " ";
        format = "via [$symbol$version( \\($virtualenv\\))]($style) ";
      };

      nix_shell = {
        symbol = " ";
        format = "via [$symbol$state( \\($name\\))]($style) ";
      };
    };
  };

  # Git
  programs.git = {
    enable = true;
    userName = "chrissiwaffler";
    userEmail = "waffler.christoph@gmail.com";

    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Catppuccin-mocha";
      };
    };

    aliases = {};

    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      fetch.prune = true;
      diff.colorMoved = "default";
      merge.conflictstyle = "diff3";

      core = {
        editor = "nvim";
        autocrlf = "input";
      };
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      "*.swo"
      "*~"
      ".idea"
      ".vscode"
      "node_modules"
      "__pycache__"
      "*.pyc"
      ".pytest_cache"
      ".mypy_cache"
      ".ruff_cache"
      "target/"
      "result"
      "result-*"
    ];
  };

  # Direnv for automatic environment loading
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
