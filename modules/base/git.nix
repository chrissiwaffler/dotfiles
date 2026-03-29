{config, ...}: {
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "Christoph Waffler";
        email = "waffler.christoph@gmail.com";
      };

      alias = {};

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
      ".claude/settings.local.json"
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Catppuccin-mocha";
    };
  };

  programs.lazygit.enable = true;
}
