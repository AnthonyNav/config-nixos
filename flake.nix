{
  description = "Toño's Master Multi-Host NixOS Configuration";

  nixConfig = {
    extra-substituters = [ "https://cache.numtide.com" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    llm-agents.url = "github:numtide/llm-agents.nix";

    herdr.url = "github:herdrdev/herdr/v0.9.3";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      username = "anthony";
      specialArgs = { inherit inputs username; };
      pkgsFor = import nixpkgs {
        localSystem = system;
        config.allowUnfree = true;
      };
      aiToolsPackages = import ./packages/ai-tools.nix {
        pkgs = pkgsFor;
        llmAgents = inputs.llm-agents.packages.${system};
      };
      herdrPackage = inputs.herdr.packages.${system}.default;
      kiroPackages = import ./packages/kiro.nix { pkgs = pkgsFor; };
      dbgatePackage = pkgsFor.callPackage ./packages/dbgate.nix { };
      dbeaverPackage = import ./packages/dbeaver.nix { pkgs = pkgsFor; };
      aiToolVersions = {
        claudeCode = aiToolsPackages.claude-code.version;
        codex = aiToolsPackages.codex.version;
        opencode = aiToolsPackages.opencode.version;
        rtk = aiToolsPackages.rtk.version;
      };
      treefmtEval = treefmt-nix.lib.evalModule pkgsFor ./treefmt.nix;
      fleet = import ./inventory/fleet.nix { };
      workstations = lib.getAttrs fleet.workstationNames fleet.hosts;
      inherit (fleet) workstationNames homeHostNames inputSharingHostNames;
      fleetNames = fleet.hostNames;
      fleetInventory = fleet.inventory;
      hostOutputs = import ./flake/hosts.nix { inherit inputs username fleet; };
      fleetEndpoints = import ./inventory/endpoints.nix { };
      tailscalePolicyConfig = import ./inventory/tailscale.nix { inherit username; };
      inherit (tailscalePolicyConfig) tailnetPolicy;
      tailnetPolicyFile = pkgsFor.writeText "tailscale-policy.json" (builtins.toJSON tailnetPolicy);
      tailscalePolicyPrinter = pkgsFor.writeShellApplication {
        name = "tailscale-policy";
        text = ''
          ${pkgsFor.jq}/bin/jq . ${tailnetPolicyFile}
        '';
      };
      nixConfigPackages = import ./modules/home/nix-config-packages.nix {
        inherit
          lib
          username
          fleetNames
          homeHostNames
          ;
        pkgs = pkgsFor;
      };
    in
    {
      lib = {
        inherit
          aiToolVersions
          fleetEndpoints
          fleetInventory
          tailnetPolicy
          workstationNames
          fleetNames
          homeHostNames
          inputSharingHostNames
          ;
        inherit (fleet)
          sshHostNames
          syncthingHostNames
          buildMatrix
          ;
      };

      nixosConfigurations = hostOutputs.nixosConfigurations // {
        installer = lib.nixosSystem {
          inherit system specialArgs;
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./iso/installer.nix
          ];
        };
      };

      inherit (hostOutputs) homeConfigurations;

      formatter.${system} = treefmtEval.config.build.wrapper;
      packages.${system} = {
        nix-config = nixConfigPackages.nixConfig;
        inherit (pkgsFor) gitleaks;
        artemis = import ./packages/artemis.nix { pkgs = pkgsFor; };
        tailscale-policy = tailscalePolicyPrinter;
        kiro-cli = kiroPackages.cli;
        kiro = kiroPackages.ide;
        herdr = herdrPackage;
        dbgate = dbgatePackage;
        sonobus = pkgsFor.callPackage ./packages/sonobus.nix { };
        orca-ide = pkgsFor.callPackage ./packages/orca-ide.nix { };
        dbeaver = dbeaverPackage;
        blender-standalone = pkgsFor.callPackage ./packages/blender-standalone.nix { };
        catppuccin-wallpapers = pkgsFor.callPackage ./packages/catppuccin-wallpapers.nix { };
      };
      apps.${system} = {
        nix-config = {
          type = "app";
          program = lib.getExe nixConfigPackages.nixConfig;
          meta.description = "Validate, build, and deploy this NixOS configuration";
        };
        tailscale-policy = {
          type = "app";
          program = lib.getExe tailscalePolicyPrinter;
          meta.description = "Render the declared Tailscale tailnet policy";
        };
      };
      checks.${system} =
        (import ./flake/checks.nix {
          inherit
            lib
            pkgsFor
            self
            username
            workstationNames
            fleetNames
            inputSharingHostNames
            workstations
            fleetEndpoints
            tailnetPolicy
            tailscalePolicyConfig
            tailscalePolicyPrinter
            treefmtEval
            aiToolsPackages
            aiToolVersions
            nixConfigPackages
            ;
        })
        // (import ./flake/fleet-checks.nix {
          inherit
            inputs
            lib
            pkgsFor
            fleet
            self
            username
            ;
        })
        // (import ./flake/ai-checks.nix {
          inherit
            lib
            self
            fleet
            username
            aiToolsPackages
            ;
          pkgs = pkgsFor;
        })
        // (import ./flake/project-checks.nix {
          inherit lib;
          pkgs = pkgsFor;
        })
        // (import ./flake/desktop-checks.nix {
          inherit
            lib
            self
            username
            workstationNames
            ;
          pkgs = pkgsFor;
        })
        // {
          maintenance-lint =
            pkgsFor.runCommand "maintenance-lint-check"
              {
                nativeBuildInputs = [
                  pkgsFor.statix
                  pkgsFor.deadnix
                ];
              }
              ''
                statix check --config ${./statix.toml} ${self}
                deadnix --fail --exclude \
                  ${self}/hosts/desktop/hardware-configuration.nix \
                  ${self}/hosts/victus/hardware-configuration.nix -- ${self}
                touch "$out"
              '';
        };
      devShells.${system}.default = pkgsFor.mkShell {
        packages = with pkgsFor; [
          treefmtEval.config.build.wrapper
          actionlint
          nixfmt
          statix
          deadnix
          shellcheck
          gitleaks
          nodejs_22
          jq
        ];
      };
    };
}
