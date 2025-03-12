{
  lib,
  fetchFromGitHub,
  pkgsCross,
  llvmPackages,
  wasm-component-ld,
}:

# A wasi-libc suitable for shared libraries.
# NOTE: Don't use 'wasm32-wasip2' here to avoid infinite recursion.

pkgsCross.wasi32.stdenvNoCC.mkDerivation {
  pname = "wasi-libc";
  version = "25.0";

  src = fetchFromGitHub {
    owner = "WebAssembly";
    repo = "wasi-libc";
    tag = "wasi-sdk-25";
    hash = "sha256-d6IW7CeBV1sLZzLtSEzlox8S3j1TOSnzOvEdvYOD84I=";
    fetchSubmodules = true;
  };

  patches = [
    ./patches/shared.patch
  ];

  postPatch = ''
    patchShebangs .

    # Disable symbol checking
    substituteInPlace Makefile \
      --replace-fail "finish: check-symbols" "# finish: check-symbols"
  '';

  outputs = [
    "out"
    "dev"
    "share"
  ];

  nativeBuildInputs = [
    wasm-component-ld
    pkgsCross.wasi32.buildPackages.llvmPackages.clang
    llvmPackages.bintools
  ];

  buildPhase = ''
    runHook preBuild

    export SYSROOT_LIB=${builtins.placeholder "out"}/lib
    export SYSROOT_INC=${builtins.placeholder "dev"}/include
    export SYSROOT_SHARE=${builtins.placeholder "share"}/share
    mkdir -p "$SYSROOT_LIB" "$SYSROOT_INC" "$SYSROOT_SHARE"

    echo "Building default"
    make \
      -j$NIX_BUILD_CORES \
      SYSROOT_LIB=$SYSROOT_LIB \
      SYSROOT_INC=$SYSROOT_INC \
      SYSROOT_SHARE=$SYSROOT_SHARE \
      default

    echo "Building libc_so"
    make \
      -j$NIX_BUILD_CORES \
      SYSROOT_LIB=$SYSROOT_LIB \
      SYSROOT_INC=$SYSROOT_INC \
      SYSROOT_SHARE=$SYSROOT_SHARE \
      libc_so

    runHook postBuild
  '';

  enableParallelBuilding = true;

  meta = {
    description = "WASI libc implementation for WebAssembly with shared library support";
    homepage = "https://wasi.dev";
    license = [
      lib.licenses.asl20-llvm
      lib.licenses.asl20
      lib.licenses.mit
    ];
    platforms = lib.platforms.all;
  };
}
