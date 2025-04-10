{
  lib,
  makeRustPlatform,
  fetchFromGitHub,
  rust-bin,
}:

let
  rust = rust-bin.stable.latest.default.override {
    targets = [
      "wasm32-unknown-unknown"
      "wasm32-wasip1"
    ];
  };

  rustPlatform = makeRustPlatform {
    cargo = rust;
    rustc = rust;
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "wasip1-component-adapter";
  version = "31.0.0";

  src = fetchFromGitHub {
    owner = "bytecodealliance";
    repo = "wasmtime";
    rev = "v${finalAttrs.version}";
    hash = "sha256-IQeYmqCXhzWsuufrLKeBI2sw86dXbn7c5DbmcoJTWvo=";
    fetchSubmodules = true;
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-zMDpbJoOaKJ974Ln43JtY3f3WOq2dEmdgX9TubYdlow=";

  buildPhase = ''
    cargo build \
      --release \
      --target wasm32-unknown-unknown \
      --package wasi-preview1-component-adapter
  '';

  installPhase = ''
    mkdir -p $out/bin
    mv target/wasm32-unknown-unknown/release/*.wasm $out/bin
  '';

  doCheck = false;

  meta = {
    description = "A bridge for the wasip1 ABI to the wasip2 component model.";
    homepage = "https://wasmtime.dev";
    changelog = "https://github.com/bytecodealliance/wasmtime/releases";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
