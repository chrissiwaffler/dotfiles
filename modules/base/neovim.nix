{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  programs.neovim = {
    enable = true;

    # Use nightly if you want bleeding edge
    package = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
    # or just use stable:
    # package = pkgs.neovim-unwrapped;

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Extra packages available to neovim
    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nil # nix LSP
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted # html, css, json, eslint
      pyright
      # ruff-lsp
      rust-analyzer
      gopls
      # clangd

      # Formatters
      stylua
      alejandra
      black
      isort
      prettierd
      rustfmt
      gofumpt

      # Tools
      tree-sitter
      nodejs
      gcc
      gnumake
      fd
      git
      lazygit

      # ML specific
      pyright
      ruff
    ];

    # Python providers
    withPython3 = true;
    withNodeJs = true;
    withRuby = false;

    # Extra python packages for neovim
    extraPython3Packages = ps:
      with ps; [
        pynvim
        jupyter-client
        ipython
        numpy
        pandas
        matplotlib
      ];
  };

  # Link your kickstart.nvim config
  xdg.configFile."nvim" = {
    source = inputs.kickstart-nvim;
    recursive = true;
  };

  # Or if you want to manage it locally in the dotfiles repo:
  # xdg.configFile."nvim".source = ../config/nvim;

  # Environment for neovim
  home.sessionVariables = {
    NVIM_LISTEN_ADDRESS = "/tmp/nvimsocket";
  };
}
