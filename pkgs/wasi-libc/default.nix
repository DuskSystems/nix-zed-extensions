{
  lib,
  fetchFromGitHub,
  pkgsCross,
}:

# A wasi-libc suitable for shared libaries.
# NOTE: Don't use 'wasm32-wasip2' here to avoid infinite recursion.

pkgsCross.wasi32.stdenv.mkDerivation {
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
  '';

  outputs = [
    "out"
    "dev"
    "share"
  ];

  makeFlags = [
    "SYSROOT_LIB=${placeholder "out"}/lib"
    "SYSROOT_INC=${placeholder "dev"}/include"
    "SYSROOT_SHARE=${placeholder "share"}/share"
    "THREAD_MODEL=single"
    "WASI_SNAPSHOT=p2"
  ];

  makeTargets = [
    "default"
    "libc_so"
  ];

  enableParallelBuilding = true;
  dontInstall = true;

  meta = {
    description = "WASI libc implementation for WebAssembly.";
    homepage = "https://wasi.dev";
    license = [
      lib.licenses.asl20-llvm
      lib.licenses.asl20
      lib.licenses.mit
    ];
    platforms = lib.platforms.all;
  };
}
