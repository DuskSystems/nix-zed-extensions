{
  lib,
  fetchFromGitHub,
  pkgsCross,
}:

# A wasi-libc suitable for shared libaries.
# NOTE: Don't use 'wasm32-wasip2' here to avoid infinite recursion.

pkgsCross.wasi32.stdenv.mkDerivation {
  pname = "wasi-libc";
  version = "e9524a0980b9bb6bb92e87a41ed1055bdda5bb86";

  src = fetchFromGitHub {
    owner = "WebAssembly";
    repo = "wasi-libc";
    tag = "wasi-sdk-25";
    hash = "sha256-d6IW7CeBV1sLZzLtSEzlox8S3j1TOSnzOvEdvYOD84I=";
    fetchSubmodules = true;
  };

  outputs = [
    "out"
    "dev"
  ];

  postPatch = ''
    patchShebangs .

    # Disable symbol checking.
    substituteInPlace Makefile \
      --replace-fail "finish: check-symbols" "# finish: check-symbols"
  '';

  makeFlags = [
    "SYSROOT_LIB=${placeholder "out"}/lib"
    "SYSROOT_INC=${placeholder "dev"}/include"
    "WASI_SNAPSHOT=p2"
    "EXTRA_CFLAGS=-fPIC"
  ];

  enableParallelBuilding = true;
  dontInstall = true;

  preFixup = ''
    cp linker-provided-symbols.txt $out/lib/linker-provided-symbols.txt
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
