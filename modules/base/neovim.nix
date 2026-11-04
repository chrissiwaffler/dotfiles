{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  # Python provider host: pynvim (remote plugin API) + molten deps (jupyter_client, nbformat).
  # Reads the extraPython3Packages option below — single source of truth.
  nvimPython = pkgs.python3.withPackages (ps:
    [ps.pynvim]
    ++ (config.programs.neovim.extraPython3Packages ps));

  # Lua env: magick rock for image.nvim (molten inline plots via kitty graphics protocol)
  nvimLua = pkgs.luajit.withPackages (ps: [ps.magick]);

  # ~/.config/nvim is a symlink to the kickstart fork, so home-manager's
  # generated init.lua — where wrapRc = false normally delivers the provider
  # config — never loads. Inject host procs + lua package paths via --cmd
  # wrapper flags instead: they run before any user init on every invocation.
  providerLua = lib.concatStringsSep ";" [
    "package.path='${pkgs.luajit.pkgs.getLuaPath nvimLua};'..package.path"
    "package.cpath='${pkgs.luajit.pkgs.getLuaCPath nvimLua};'..package.cpath"
    "vim.g.python3_host_prog='${nvimPython}/bin/python3'"
    "vim.g.node_host_prog='${pkgs.neovim-node-client}/bin/neovim-node-host'"
  ];
in {
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

    # Extra python packages for neovim (the host env in `nvimPython` adds these + pynvim)
    extraPython3Packages = ps:
      with ps; [
        jupyter-client # molten-nvim kernel communication
        nbformat # molten import/export of .ipynb outputs
        numpy
        pandas
        # matplotlib  # Commented out due to tkinter build issues
      ];

    # Lua packages for the wrapped nvim (same env as nvimLua above)
    extraLuaPackages = ps: [ps.magick];

    # Provider/lua injection for symlinked-config setups (see providerLua above)
    extraWrapperArgs = [
      "--add-flags"
      ''--cmd "lua ${providerLua}"''
    ];
  };

  # Link your kickstart.nvim config
  xdg.configFile."nvim" = {
    source = inputs.kickstart-nvim;
    recursive = true;
  };
}
