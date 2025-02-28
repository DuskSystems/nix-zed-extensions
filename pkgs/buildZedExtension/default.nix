{
  lib,
  stdenv,
  pkgsCross,
  llvmPackages,
  nix-zed-extensions,
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
    if (kind == "rust") then pkgsCross.wasm32-wasip2.rustPlatform.buildRustPackage else stdenv.mkDerivation;
in
buildZedExtension (
  {
    pname = "zed-extension-${name}";
    inherit version src;

    RUSTFLAGS = "-C linker=${llvmPackages.lld}/bin/lld";

    postBuild = ''
      ${lib.optionalString (kind == "rust") ''
        # Rust WASM
        cp target/wasm32-wasip2/release/*.wasm extension.wasm
      ''}

      # Manifest
      ${lib.getExe nix-zed-extensions} populate
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
