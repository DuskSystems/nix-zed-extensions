final: prev: {
  buildZedExtension = prev.callPackage ../pkgs/buildZedExtension { };
  buildZedGrammar = prev.callPackage ../pkgs/buildZedGrammar { };

  nix-zed-extensions = prev.callPackage ../pkgs/nix-zed-extensions { };

  wasi-sdk = prev.callPackage ../pkgs/wasi-sdk { };
  wasm-component-ld = prev.callPackage ../pkgs/wasm-component-ld { };

  # Allow pre-fetching cargoHash.
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/rust/fetch-cargo-vendor.nix
  fetch-cargo-vendor-util = prev.writers.writePython3Bin "fetch-cargo-vendor-util" {
    libraries = with prev.python3Packages; [
      requests
    ];
    flakeIgnore = [
      "E501"
    ];
  } (builtins.readFile "${prev.path}/pkgs/build-support/rust/fetch-cargo-vendor-util.py");

  pkgsCross = prev.pkgsCross // {
    wasm32-wasip2 = prev.pkgsCross.wasm32-wasip2 // {
      # Fix rustc build:
      # - https://github.com/NixOS/nixpkgs/issues/380389
      # - https://github.com/NixOS/nixpkgs/pull/323161
      # - https://github.com/NixOS/nixpkgs/pull/330037
      # - https://github.com/NixOS/nixpkgs/pull/379632
      buildPackages = prev.pkgsCross.wasm32-wasip2.buildPackages // {
        rustc = prev.pkgsCross.wasm32-wasip2.buildPackages.rustc.override {
          rustc-unwrapped = prev.pkgsCross.wasm32-wasip2.buildPackages.rustc.unwrapped.overrideAttrs (_: {
            LD_LIBRARY_PATH = "${final.llvmPackages.libunwind}/lib";
            WASI_SDK_PATH = "${final.wasi-sdk}";
          });

          sysroot = prev.buildEnv {
            name = "rustc-sysroot";
            paths = [
              final.pkgsCross.wasm32-wasip2.buildPackages.rustc.unwrapped
              final.llvmPackages.libunwind
            ];
          };
        };

        cargo = prev.pkgsCross.wasm32-wasip2.buildPackages.cargo.override {
          inherit (final.pkgsCross.wasm32-wasip2.buildPackages) rustc;
        };
      };

      rustPlatform = prev.pkgsCross.wasm32-wasip2.makeRustPlatform {
        inherit (final.pkgsCross.wasm32-wasip2.buildPackages) cargo rustc;
      };
    };
  };

  data = builtins.fromJSON (builtins.readFile ../extensions.json);

  mkZedGrammar =
    grammar:

    {
      buildZedGrammar,
      fetchgit,
    }:

    buildZedGrammar {
      inherit (grammar) name version;

      src = fetchgit {
        inherit (grammar.src)
          url
          rev
          hash
          fetchLFS
          fetchSubmodules
          deepClone
          leaveDotGit
          ;
      };
    };

  zed-grammars = builtins.listToAttrs (
    map (grammar: {
      name = grammar.id;
      value = final.callPackage (final.mkZedGrammar grammar) { };
    }) final.data.grammars
  );

  mkZedExtension =
    extension:

    {
      buildZedExtension,
      fetchgit,
      zed-grammars,
    }:

    buildZedExtension (
      {
        inherit (extension) version kind;
        name = extension.id;

        src = fetchgit {
          inherit (extension.src)
            url
            rev
            hash
            fetchLFS
            fetchSubmodules
            deepClone
            leaveDotGit
            ;
        };

        grammars = map (id: zed-grammars."${id}") extension.grammars;
      }
      // (
        if extension.kind == "rust" then
          {
            inherit (extension) useFetchCargoVendor cargoHash;
          }
        else
          { }
      )
    );

  zed-extensions = builtins.listToAttrs (
    map (extension: {
      name = extension.id;
      value = final.callPackage (final.mkZedExtension extension) {
        inherit (final) zed-grammars;
      };
    }) final.data.extensions
  );
}
