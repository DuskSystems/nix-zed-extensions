{
  pkgsCross,
  ...
}:

{
  name,
  version,
  src,
  ...
}@attrs:

# NOTE: https://github.com/llvm/llvm-project/issues/103592

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

      $CC \
        -fPIC \
        -shared \
        -Os \
        -Wl,--export=tree_sitter_${name} \
        -Wl,--allow-undefined \
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
