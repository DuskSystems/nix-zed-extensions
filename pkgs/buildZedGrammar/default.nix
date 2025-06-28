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
    "grammarRoot"
  ];

  extendDrvArgs =
    finalAttrs:

    {
      name,
      src,
      version,
      grammarRoot ? null,
      ...
    }:

    let
      grammarDir = if grammarRoot == null then "." else grammarRoot;
    in
    {
      pname = "zed-grammar-${name}";
      inherit name src version;

      buildInputs = [
        wasi-sdk
      ];

      buildPhase = ''
        mkdir -p $out/share/zed/grammars

        pushd ${grammarDir}

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

        popd
      '';

      doCheck = false;
      dontInstall = true;
    };
}
