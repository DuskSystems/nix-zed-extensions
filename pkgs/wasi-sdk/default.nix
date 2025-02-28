{
  lib,
  stdenv,
  wasi-libc,
}:

# A mock wasi-sdk, which mimics the real thing just enough for rustc to build.

stdenv.mkDerivation {
  name = "wasi-sdk";
  version = wasi-libc.version;

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/share/wasi-sysroot/lib/wasm32-wasip2
    cp -r ${wasi-libc}/lib/* $out/share/wasi-sysroot/lib/wasm32-wasip2
  '';

  meta = {
    description = "WASI SDK for compiling C/C++ to WebAssembly.";
    homepage = "https://github.com/WebAssembly/wasi-sdk";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
