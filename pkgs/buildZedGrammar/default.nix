{
  pkgsCross,
  wasi-libc,
  ...
}:

{
  name,
  version,
  src,
  ...
}@attrs:

pkgsCross.wasm32-wasip2.stdenv.mkDerivation (
  {
    pname = "zed-grammar-${name}";
    inherit src version;

    buildPhase = ''
      runHook preBuild

      mkdir -p $out/grammars

      SRC="src/parser.c"
      if [ -f src/scanner.c ]; then
        SRC="$SRC src/scanner.c"
      fi

      wasm32-unknown-wasi-clang \
        -fPIC \
        -shared \
        -Os \
        -Wl,--allow-undefined-file=${wasi-libc.share}/share/undefined-symbols.txt \
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
