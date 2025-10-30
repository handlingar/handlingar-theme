{
  config,
  pkgs,
  lib,
  hostname,
  inputs,
  ...
}:
let
  a = 1;
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    ./modules/alaveteli.nix
    (import "${inputs.alaveteli-flake}/nix/module.nix" inputs.alaveteli-flake {
      inherit
        config
        inputs
        lib
        pkgs
        ;
    })
  ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub = {
    enable = true;
    configurationLimit = 10;
  };

  services.openssh.enable = true;

  # TODO: change users once the initial setup works ok-ish, this makes it
  # easier to iterate on config
  users.users.root = {
    openssh.authorizedKeys.keys = [
      # id_ed25519
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDdvOXs4OY6wdyNYXN43HUACaQZLO3bAy9eUsgP2dZu laurent@where.tf"
      # id_ed25519_dada_hetzner
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIntmiRGy/nQTd0URD8Mhf9olO9ZjLRXWP+UnbYLexLa laurent@where.tf"
    ];
  };

  environment.systemPackages = [
    pkgs.inetutils
    pkgs.nettools
    pkgs.ripgrep
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # to help debug networking config
  systemd.services."systemd-networkd".environment.SYSTEMD_LOG_LEVEL = "debug";

  system.stateVersion = "25.11";
}
