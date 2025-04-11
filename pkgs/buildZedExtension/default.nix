{
  lib,
  stdenvNoCC,
  nix-zed-extensions,
  ...
}:

lib.extendMkDerivation {
  constructDrv = stdenvNoCC.mkDerivation;

  excludeDrvArgNames = [
    "name"
    "version"
    "src"
    "grammars"
  ];

  extendDrvArgs =
    finalAttrs:

    {
      name,
      version,
      src,
      grammars ? [ ],
      ...
    }:

    {
      pname = "zed-extension-${name}";
      inherit version src;

      nativeBuildInputs = [
        nix-zed-extensions
      ];

      postBuild = ''
        # Manifest
        nix-zed-extensions populate
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out/share/zed/extensions/${name}

        # Manifest
        cp extension.toml $out/share/zed/extensions/${name}

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

        runHook postInstall
      '';

      doCheck = false;
    };
}
