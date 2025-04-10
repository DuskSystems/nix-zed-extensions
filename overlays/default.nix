final: prev: {
  buildZedExtension = prev.callPackage ../pkgs/buildZedExtension { };
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
