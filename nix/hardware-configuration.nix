{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # see https://wiki.nixos.org/wiki/Install_NixOS_on_Hetzner_Cloud#Network_configuration
  systemd.network.enable = true;
  systemd.network.networks."30-wan" = {
    matchConfig.Name = "enp1s0"; # either ens3 or enp1s0, check 'ip addr'
    networkConfig.DHCP = "ipv4";
    address = [
      "2a01:4f9:c012:386e::1/64"
    ];
    routes = [
      { Gateway = "fe80::1"; }
    ];
  };
}
