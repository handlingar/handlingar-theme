{
  description = "Ruby environment for Ma Dada theme development using devenv.sh";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs = {
        nixpkgs = {
          follows = "nixpkgs";
        };
      };
    };
    nixpkgsrspamd = {
      url = "github:laurents/nixpkgs/fix-rspamd-config-file";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    # TODO: GIT_WORK_TREE and GIT_DIR break `nix flake update|lock...` is this ok?
    alaveteli-flake = {
      # url = "git+https://github.com/laurents/alaveteli?ref=nix-devenv";
      # url = "git+https://github.com/laurents/alaveteli_not_fork";
      inputs.nixpkgs.follows = "nixpkgs";
      #   # FIXME: doesn't like submodules in path input
      #   # url = "git+ssh://git@github.com/laurents/alaveteli?ref=nix-devenv";
      #   # git+file does work with submodules
      url = "git+file:/home/laurent/Sites/dada/alaveteli_dev";
    };
  };

  # see messages at 20:38 on 15/09 in lix dev channel about lockfile contents

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    {
      self,
      nixpkgs,
      sops-nix,
      alaveteli-flake,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import alaveteli-flake.inputs.systems);
      devenv = alaveteli-flake.inputs.devenv;
    in
    {
      nixosConfigurations = {
        # configurations for Ma Dada servers
        staging = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./nix/configuration.nix
            inputs.disko.nixosModules.disko

            sops-nix.nixosModules.sops
            {
              sops = {
                # TODO: move sops scripts into alaveteli so all installs
                # use the same mechanism
                # https://lgug2z.com/articles/handling-secrets-in-nixos-an-overview/#sops-nix
                defaultSopsFile = ./nix/secrets.yaml;
                age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
                secrets = {
                  "alaveteli_db_password" = {
                    owner = "alaveteli";
                  };
                  maxmind_license_key = {
                    # owner = "geoip";
                  };
                };
              };
            }
          ];
          # Example how to pass an arg to configuration.nix:
          specialArgs = {
            inherit inputs;
            hostname = "staging";
          };
        };
      };
    };
}
