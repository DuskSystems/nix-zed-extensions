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
        nix-zed-extensions
      ];

      buildPhase = ''
        runHook preBuild

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
