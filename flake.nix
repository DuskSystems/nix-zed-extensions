{
  description = "nix-zed-extensions";

  nixConfig = {
    extra-substituters = [ "https://nix-zed-extensions.cachix.org" ];
    extra-trusted-public-keys = [ "nix-zed-extensions.cachix.org-1:+8tBcRBR66BzaedNWGDDG/hPA4g3SaEFJJDqrYNaawM=" ];
  };

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-24.11";
    };
  };

  # nix flake show
  outputs =
    {
      self,
      nixpkgs,
      ...
    }:

    let
      perSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      systemPkgs = perSystem (
        system:

        import nixpkgs {
          inherit system;

          overlays = [
            self.overlays.default
          ];
        }
      );

      perSystemPkgs = f: perSystem (system: f (systemPkgs.${system}));
    in
    {
      overlays = {
        default = nixpkgs.lib.composeManyExtensions [
          (import ./overlays/cross.nix)
          (import ./overlays/packages.nix)
        ];
      };

      homeManagerModules = {
        default = import ./modules/home-manager;
      };

      # nix build .#<name>
      packages = perSystemPkgs (pkgs: {
        nix-zed-extensions = pkgs.nix-zed-extensions;

        zed-grammars = pkgs.zed-grammars;
        zed-extensions = pkgs.zed-extensions;
      });

      apps = perSystemPkgs (pkgs: {
        default = {
          type = "app";
          program = "${pkgs.nix-zed-extensions}/bin/nix-zed-extensions";
        };
      });

      devShells = perSystemPkgs (pkgs: {
        # nix develop
        default = pkgs.mkShell {
          name = "nix-zed-extensions-shell";

          env = {
            # Nix
            NIX_PATH = "nixpkgs=${nixpkgs.outPath}";

            # Rust
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };

          buildInputs = with pkgs; [
            # Rust
            rustc
            cargo
            clippy
            rustfmt
            rust-analyzer

            # Fetch
            fetch-cargo-vendor-util
            nix-prefetch-git

            # TOML
            taplo

            # Nix
            nixfmt-rfc-style
            nixd
            nil
          ];
        };
      });
    };
}
