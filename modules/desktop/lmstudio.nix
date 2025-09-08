{
  config,
  pkgs,
  ...
}: {
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      lmstudio
    ];
  };

  # note: LM Studio (Desktop) needs to be run at least once before we can use `lms`
  # https://lmstudio.ai/docs/cli

  # Firewall configuration to expose the LM Studio port on 1234
  networking.firewall = {
    allowedTCPPorts = [1234];
  };

  # adding what ~/.lmstudio/bin/lms bootstrap would also do
  # programs.zsh = {
  #   enable = true;
  #   shellAliases = {
  #     lms = "/home/chrissi/.lmstudio/bin/lms";
  #   };
  # };
}
