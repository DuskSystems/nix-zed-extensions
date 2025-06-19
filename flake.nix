{
  description = "nix-zed-extensions";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-25.05";
    };

    nixpkgs-deprecated = {
      url = "github:NixOS/nixpkgs/nixos-24.11";
    };

    nixpkgs-unstable = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
    };
  };

  # nix flake show
  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
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
          rust-overlay.overlays.default
          (import ./overlays)
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

        wasi-sdk = pkgs.wasi-sdk;
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
            taplo
            cargo-outdated

            # WASM
            wasm-tools

            # Fetch
            fetch-cargo-vendor-util
            nix-prefetch-git

            # CLI
            tree

            # GitHub
            zizmor

            # Nix
            nix-update
            nixfmt-rfc-style
            nixd
            nil
          ];
        };
      });
    };
}
