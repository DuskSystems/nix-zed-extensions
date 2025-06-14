{
  lib,
  stdenvNoCC,
  wasi-sdk,
  ...
}:

lib.extendMkDerivation {
  constructDrv = stdenvNoCC.mkDerivation;

  excludeDrvArgNames = [
    "name"
    "src"
    "version"
  ];

  extendDrvArgs =
    finalAttrs:

    {
      name,
      src,
      version,
      ...
    }:

    {
      pname = "zed-grammar-${name}";
      inherit name src version;

      buildInputs = [
        wasi-sdk
      ];

      buildPhase = ''
        runHook preBuild

        mkdir -p $out/share/zed/grammars

        SRC="src/parser.c"
        if [ -f src/scanner.c ]; then
          SRC="$SRC src/scanner.c"
        fi

        clang \
          --target=wasm32-wasip2 \
          --sysroot=${wasi-sdk}/share/wasi-sysroot \
          -fPIC \
          -shared \
          -Os \
          -Wl,--export=tree_sitter_${name} \
          -o $out/share/zed/grammars/${name}.wasm \
          -I src \
          $SRC

        runHook postBuild
      '';

      doCheck = false;
      dontInstall = true;
    };
}
