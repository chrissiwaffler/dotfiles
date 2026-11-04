{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  programs.neovim = {
    enable = true;

    # Use stable from nixpkgs
    package = pkgs.neovim-unwrapped;

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Extra packages available to neovim
    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nil # nix LSP
      typescript-language-server
      vscode-langservers-extracted # html, css, json, eslint
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
      biome
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
      (pkgs.python3Packages.jupytext) # .ipynb <-> plaintext CLI (jupytext.nvim)

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
        jupyter-client # molten-nvim kernel communication
        nbformat # molten import/export of .ipynb outputs
        numpy
        pandas
        # matplotlib  # Commented out due to tkinter build issues
      ];

    # Lua packages: magick rock for image.nvim (molten inline plots, kitty protocol)
    extraLuaPackages = ps: [ps.magick];
  };

  # Link your kickstart.nvim config
  xdg.configFile."nvim" = {
    source = inputs.kickstart-nvim;
    recursive = true;
  };
}
