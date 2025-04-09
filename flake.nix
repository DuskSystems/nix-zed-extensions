{
  description = "nix-zed-extensions";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
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
        wasip1-component-adapter = pkgs.wasip1-component-adapter;
        wasm-component-ld = pkgs.wasm-component-ld;
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
            cargo-outdated

            # WASM
            wasm-tools

            # Fetch
            fetch-cargo-vendor-util
            nix-prefetch-git

            # TOML
            taplo

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
