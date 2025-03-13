{
  stdenvNoCC,
  wasi-sdk,
  ...
}:

{
  name,
  version,
  src,
  ...
}@attrs:

stdenvNoCC.mkDerivation (
  {
    pname = "zed-grammar-${name}";
    inherit src version;

    buildInputs = [
      wasi-sdk
    ];

    buildPhase = ''
      runHook preBuild

      mkdir -p $out/grammars

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
        -o $out/grammars/${name}.wasm \
        -I src \
        $SRC

      runHook postBuild
    '';

    doCheck = false;
    dontInstall = true;
  }
  // attrs
)
