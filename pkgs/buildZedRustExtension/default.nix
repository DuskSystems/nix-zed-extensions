{
  lib,
  stdenv,
  makeRustPlatform,
  rust-bin,
  clang,
  wasm-tools,
  jq,
  nix-zed-extensions,
  ...
}:

let
  rust = rust-bin.stable.latest.default.override {
    targets = [ "wasm32-wasip2" ];
  };

  rustPlatform = makeRustPlatform {
    cargo = rust;
    rustc = rust;
  };
in
lib.extendMkDerivation {
  constructDrv = rustPlatform.buildRustPackage;

  excludeDrvArgNames = [
    "name"
    "src"
    "version"
    "extensionRoot"
    "grammars"
  ];

  extendDrvArgs =
    finalAttrs:

    {
      name,
      src,
      version,
      extensionRoot ? null,
      grammars ? [ ],
      ...
    }:

    {
      pname = "zed-extension-${name}";
      inherit name src version;

      nativeBuildInputs = [
        clang
        wasm-tools
        jq
        nix-zed-extensions
      ];

      buildPhase = ''
        runHook preBuild

        ${lib.optionalString (extensionRoot != null) ''
          pushd ${extensionRoot}
        ''}

        # Rust
        cargo build \
          --release \
          --target wasm32-wasip2

        ${lib.optionalString (extensionRoot != null) ''
          popd
        ''}

        # WASM
        mv target/wasm32-wasip2/release/*.wasm extension.wasm
        wasm-tools metadata show extension.wasm
        wasm-tools validate extension.wasm

        # Ensure this is actually a WASI component, not a module
        if ! wasm-tools metadata show --json extension.wasm | jq -e '.component' > /dev/null; then
          echo "Failed to produce a WASI component"
          exit 1
        fi

        ${lib.optionalString (extensionRoot != null) ''
          pushd ${extensionRoot}
        ''}

        # Manifest
        nix-zed-extensions populate

        ${lib.optionalString (extensionRoot != null) ''
          popd
        ''}

        runHook postBuild
      '';

      doCheck = true;
      checkPhase = ''
        runHook preCheck

        ${lib.optionalString (extensionRoot != null) ''
          pushd ${extensionRoot}
        ''}

        # Checks
        nix-zed-extensions check ${name} ${lib.concatMapStringsSep " " (grammar: grammar.name) grammars}

        ${lib.optionalString (extensionRoot != null) ''
          popd
        ''}

        runHook postCheck
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out/share/zed/extensions/${name}

        ${lib.optionalString (extensionRoot != null) ''
          pushd ${extensionRoot}
        ''}

        # Manifest
        cp extension.toml $out/share/zed/extensions/${name}

        # WASM
        if [ -f "extension.wasm" ]; then
          cp extension.wasm $out/share/zed/extensions/${name}
        fi

        # Grammars
        ${lib.concatMapStrings (grammar: ''
          mkdir -p $out/share/zed/extensions/${name}/grammars
          ln -s ${grammar}/share/zed/grammars/* $out/share/zed/extensions/${name}/grammars
        '') grammars}

        # Assets
        for DIR in themes icons icon_themes languages; do
          if [ -d "$DIR" ]; then
            mkdir -p $out/share/zed/extensions/${name}/$DIR
            cp -r $DIR/* $out/share/zed/extensions/${name}/$DIR
          fi
        done

        # Snippets
        if [ -f "snippets.json" ]; then
          cp snippets.json $out/share/zed/extensions/${name}
        fi

        ${lib.optionalString (extensionRoot != null) ''
          popd
        ''}

        runHook postInstall
      '';
    };
}
