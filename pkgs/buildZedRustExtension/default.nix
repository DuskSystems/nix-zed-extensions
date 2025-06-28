{
  lib,
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
    "cargoRoot"
    "grammars"
  ];

  extendDrvArgs =
    finalAttrs:

    {
      name,
      src,
      version,
      extensionRoot ? null,
      cargoRoot ? null,
      grammars ? [ ],
      ...
    }:

    let
      extensionDir = if extensionRoot == null then (if cargoRoot == null then "." else cargoRoot) else extensionRoot;
    in
    {
      pname = "zed-extension-${name}";
      inherit
        name
        src
        version
        cargoRoot
        ;

      nativeBuildInputs = [
        clang
        wasm-tools
        jq
        nix-zed-extensions
      ];

      buildPhase = ''
        # Rust
        pushd ${extensionDir}
        cargo build --release --target wasm32-wasip2 --target-dir target
        popd

        # WASM
        mv ${extensionDir}/target/wasm32-wasip2/release/*.wasm ${extensionDir}/extension.wasm
        wasm-tools metadata show ${extensionDir}/extension.wasm
        wasm-tools validate ${extensionDir}/extension.wasm

        if ! wasm-tools metadata show --json ${extensionDir}/extension.wasm | jq -e '.component' > /dev/null; then
          echo "Failed to produce a WASI component"
          exit 1
        fi

        # Manifest
        pushd ${extensionDir}
        nix-zed-extensions populate
        popd
      '';

      checkPhase = ''
        # Checks
        pushd ${extensionDir}
        nix-zed-extensions check ${name} ${lib.concatMapStringsSep " " (grammar: grammar.name) grammars}
        popd
      '';

      installPhase = ''
        mkdir -p $out/share/zed/extensions/${name}

        # WASM
        cp ${extensionDir}/extension.wasm $out/share/zed/extensions/${name}

        # Manifest
        cp ${extensionDir}/extension.toml $out/share/zed/extensions/${name}

        # Assets
        for DIR in themes icons icon_themes languages; do
          if [ -d "${extensionDir}/$DIR" ]; then
            mkdir -p $out/share/zed/extensions/${name}/$DIR
            cp -r ${extensionDir}/$DIR/* $out/share/zed/extensions/${name}/$DIR
          fi
        done

        # Snippets
        if [ -f "${extensionDir}/snippets.json" ]; then
          cp ${extensionDir}/snippets.json $out/share/zed/extensions/${name}
        fi

        # Grammars
        ${lib.concatMapStrings (grammar: ''
          mkdir -p $out/share/zed/extensions/${name}/grammars
          ln -s ${grammar}/share/zed/grammars/* $out/share/zed/extensions/${name}/grammars
        '') grammars}
      '';
    };
}
