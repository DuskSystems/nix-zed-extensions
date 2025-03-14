{
  lib,
  stdenv,
  pkgsCross,
  llvmPackages,
  wasip1-component-adapter,
  wasm-tools,
  nix-zed-extensions,
  libiconv,
}:

{
  name,
  version,
  src,
  kind ? null,
  grammars ? [ ],
  ...
}@attrs:

let
  buildZedExtension =
    if (kind == "rust") then pkgsCross.wasm32-wasip1.rustPlatform.buildRustPackage else stdenv.mkDerivation;
in
buildZedExtension (
  {
    pname = "zed-extension-${name}";
    inherit version src;

    RUSTFLAGS = "-C linker=${llvmPackages.lld}/bin/lld";
    LIBRARY_PATH = lib.optionalString stdenv.isDarwin "${libiconv}/lib";

    nativeBuildInputs = [
      wasm-tools
      nix-zed-extensions
    ];

    postBuild = ''
      ${lib.optionalString (kind == "rust") ''
        # Rust WASM
        wasm-tools component new target/wasm32-wasip1/release/*.wasm \
          --adapt wasi_snapshot_preview1=${wasip1-component-adapter}/bin/wasi_snapshot_preview1.wasm \
          --output extension.wasm

        wasm-tools validate extension.wasm
      ''}

      # Manifest
      nix-zed-extensions populate
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/extensions/installed/${name}

      # Manifest
      cp extension.toml $out/extensions/installed/${name}

      # WASM
      if [ -f "extension.wasm" ]; then
        cp extension.wasm $out/extensions/installed/${name}
      fi

      # Grammars
      ${lib.concatMapStrings (grammar: ''
        mkdir -p $out/extensions/installed/${name}/grammars
        cp -r ${grammar}/grammars/* $out/extensions/installed/${name}/grammars
      '') grammars}

      # Assets
      for DIR in themes icons icon_themes languages; do
        if [ -d "$DIR" ]; then
          mkdir -p $out/extensions/installed/${name}/$DIR
          cp -r $DIR/* $out/extensions/installed/${name}/$DIR
        fi
      done

      # Snippets
      if [ -f "snippets.json" ]; then
        cp snippets.json $out/extensions/installed/${name}
      fi

      runHook postInstall
    '';

    doCheck = false;
  }
  // removeAttrs attrs [
    "kind"
    "grammars"
  ]
)
