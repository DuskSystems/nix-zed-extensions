final: prev: {
  buildZedExtension = prev.callPackage ../pkgs/buildZedExtension { };
  buildZedRustExtension = prev.callPackage ../pkgs/buildZedRustExtension { };
  buildZedGrammar = prev.callPackage ../pkgs/buildZedGrammar { };

  nix-zed-extensions = prev.callPackage ../pkgs/nix-zed-extensions { };

  wasi-sdk = prev.callPackage ../pkgs/wasi-sdk { };
  wasip1-component-adapter = prev.callPackage ../pkgs/wasip1-component-adapter { };

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

  zed-generated-data = builtins.fromJSON (builtins.readFile ../extensions.json);

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
    }) final.zed-generated-data.grammars
  );

  mkZedExtension =
    extension:

    {
      lib,
      buildZedExtension,
      buildZedRustExtension,
      fetchgit,
      zed-grammars,
    }:

    (if extension.kind == "rust" then buildZedRustExtension else buildZedExtension) (
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

        postPatch = lib.optionalString (extension.kind == "rust" && extension ? cargoLock) ''
          cp ${../. + extension.cargoLock.lockFile} Cargo.lock
        '';

        grammars = map (id: zed-grammars."${id}") extension.grammars;
      }
      // lib.optionalAttrs (extension.kind == "rust") {
        useFetchCargoVendor = true;
        cargoHash = extension.cargoHash;
      }
      // lib.optionalAttrs (extension.kind == "rust" && extension ? cargoLock) {
        cargoLock = {
          lockFile = ../. + extension.cargoLock.lockFile;
          allowBuiltinFetchGit = true;
        };
      }
    );

  zed-extensions = builtins.listToAttrs (
    map (extension: {
      name = extension.id;
      value = final.callPackage (final.mkZedExtension extension) {
        inherit (final) zed-grammars;
      };
    }) final.zed-generated-data.extensions
  );
}
