{
  lib,
  stdenvNoCC,
  pkgsCross,
  llvmPackages,
  lld,
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
      inherit src version;

      nativeBuildInputs = [
        llvmPackages.clang-unwrapped
        lld
      ];

      buildPhase = ''
        mkdir -p $out/share/zed/grammars

        pushd ${grammarDir}

        SRC="src/parser.c"
        if [ -f src/scanner.c ]; then
          SRC="$SRC src/scanner.c"
        fi

        clang \
          --target=wasm32-wasi \
          -Os \
          -nostartfiles \
          -nodefaultlibs \
          --include-directory=src \
          -isystem ${pkgsCross.wasi32.wasilibc.dev}/include \
          --output=$out/share/zed/grammars/${name}.wasm \
          $SRC \
          "${pkgsCross.wasi32.wasilibc}/lib/libc.a" \
          "${pkgsCross.wasi32.llvmPackages.compiler-rt}/lib/wasi/libclang_rt.builtins-wasm32.a" \
          -Wl,--no-entry \
          -Wl,--allow-undefined \
          -Wl,--export=tree_sitter_${name}

        popd
      '';

      dontInstall = true;
    };
}
