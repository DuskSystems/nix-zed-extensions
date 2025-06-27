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

    let
      extensionDir = if extensionRoot != null then extensionRoot else ".";
    in
    {
      pname = "zed-extension-${name}";
      inherit name src version;

      nativeBuildInputs = [
        nix-zed-extensions
      ];

      buildPhase = ''
        # Manifest
        pushd ${extensionDir}
        nix-zed-extensions populate
        popd
      '';

      doCheck = true;
      checkPhase = ''
        # Checks
        pushd ${extensionDir}
        nix-zed-extensions check ${name} ${lib.concatMapStringsSep " " (grammar: grammar.name) grammars}
        popd
      '';

      installPhase = ''
        mkdir -p $out/share/zed/extensions/${name}

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
