{
  lib,
  fetchFromGitHub,
  pkgsCross,
}:

# A wasi-libc suitable for shared libaries.
# NOTE: Don't use 'wasm32-wasip2' here to avoid infinite recursion.

pkgsCross.wasi32.stdenv.mkDerivation {
  pname = "wasi-libc";
  version = "21.0";

  src = fetchFromGitHub {
    owner = "WebAssembly";
    repo = "wasi-libc";
    tag = "wasi-sdk-21";
    hash = "sha256-1LsMpO29y79twVrUsuM/JvC7hK8O6Yey4Ard/S3Mvvc=";
    fetchSubmodules = true;
  };

  patches = [
    ./patches/undefined-symbols.patch
    ./patches/predefined-macros.patch
  ];

  outputs = [
    "out"
    "dev"
    "share"
  ];

  postPatch = ''
    patchShebangs .
  '';

  makeFlags = [
    "SYSROOT_LIB=${placeholder "out"}/lib"
    "SYSROOT_INC=${placeholder "dev"}/include"
    "SYSROOT_SHARE=${placeholder "share"}/share"
    "WASI_SNAPSHOT=p2"
    "EXTRA_CFLAGS=-fPIC"
  ];

  enableParallelBuilding = true;
  dontInstall = true;

  preFixup = ''
    ln -s $share/share/undefined-symbols.txt $out/lib/wasi.imports
  '';

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
