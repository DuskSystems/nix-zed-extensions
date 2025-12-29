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
    map (
      filename:
      let
        id = prev.lib.removeSuffix ".json" filename;
        grammar = builtins.fromJSON (builtins.readFile (../generated/grammars + "/${filename}"));
      in
      {
        name = id;
        value = final.callPackage (final.mkZedGrammar grammar) { };
      }
    ) (builtins.filter (f: prev.lib.hasSuffix ".json" f) (builtins.attrNames (builtins.readDir ../generated/grammars)))
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
    map (
      filename:
      let
        extension = builtins.fromJSON (builtins.readFile (../generated/extensions + "/${filename}"));
      in
      {
        inherit (extension) name;
        value = final.callPackage (final.mkZedExtension extension) {
          inherit (final) zed-grammars;
        };
      }
    ) (builtins.filter (f: prev.lib.hasSuffix ".json" f) (builtins.attrNames (builtins.readDir ../generated/extensions)))
  );
}
