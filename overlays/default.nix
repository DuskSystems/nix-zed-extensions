final: prev: {
  buildZedExtension = prev.callPackage ../pkgs/buildZedExtension { };
  buildZedRustExtension = prev.callPackage ../pkgs/buildZedRustExtension { };
  buildZedGrammar = prev.callPackage ../pkgs/buildZedGrammar { };

  nix-zed-extensions = prev.callPackage ../pkgs/nix-zed-extensions { };

  wasi-sdk = prev.callPackage ../pkgs/wasi-sdk { };

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
      inherit (grammar) name version grammarRoot;

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
        inherit (extension) name version extensionRoot;

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
      // lib.optionalAttrs (extension.kind == "rust") {
        inherit (extension) cargoRoot cargoHash;
      }
      // lib.optionalAttrs (extension.kind == "rust" && extension ? cargoLock) {
        postPatch = ''
          ${
            if extension.cargoRoot != null then
              "cp ${../. + extension.cargoLock.lockFile} ${extension.cargoRoot}/Cargo.lock"
            else
              "cp ${../. + extension.cargoLock.lockFile} Cargo.lock"
          }
        '';

        cargoLock = {
          lockFile = ../. + extension.cargoLock.lockFile;
          outputHashes = extension.cargoLock.outputHashes;
          allowBuiltinFetchGit = true;
        };
      }
    );

  zed-extensions = builtins.listToAttrs (
    map (extension: {
      inherit (extension) name;

      value = final.callPackage (final.mkZedExtension extension) {
        inherit (final) zed-grammars;
      };
    }) final.zed-generated-data.extensions
  );
}
