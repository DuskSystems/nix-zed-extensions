{
  lib,
  stdenv,
  makeRustPlatform,
  rust-bin,
  llvmPackages,
  wasip1-component-adapter,
  clang,
  wasm-tools,
  nix-zed-extensions,
  libiconv,
  ...
}:

let
  rust = rust-bin.stable.latest.default.override {
    targets = [ "wasm32-wasip1" ];
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
      inherit src version;

      RUSTFLAGS = "-C linker=${llvmPackages.lld}/bin/lld";
      LIBRARY_PATH = lib.optionalString stdenv.isDarwin "${libiconv}/lib";

      nativeBuildInputs = [
        clang
        wasm-tools
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
          --target wasm32-wasip1

        ${lib.optionalString (extensionRoot != null) ''
          popd
        ''}

        # WASM
        wasm-tools component new target/wasm32-wasip1/release/*.wasm \
          --adapt wasi_snapshot_preview1=${wasip1-component-adapter}/bin/wasi_snapshot_preview1.wasm \
          --output extension.wasm

        wasm-tools validate extension.wasm

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

      doCheck = false;
    };
}
