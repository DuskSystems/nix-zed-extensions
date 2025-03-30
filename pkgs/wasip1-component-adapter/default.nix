{
  lib,
  pkgsCross,
  fetchFromGitHub,
  llvmPackages,
}:

pkgsCross.wasm32-wasip1.rustPlatform.buildRustPackage (finalAttrs: {
  pname = "wasip1-component-adapter";
  version = "31.0.0";

  src = fetchFromGitHub {
    owner = "bytecodealliance";
    repo = "wasmtime";
    rev = "v${finalAttrs.version}";
    hash = "sha256-IQeYmqCXhzWsuufrLKeBI2sw86dXbn7c5DbmcoJTWvo=";
    fetchSubmodules = true;
  };

  RUSTFLAGS = "-C linker=${llvmPackages.lld}/bin/lld";

  useFetchCargoVendor = true;
  cargoHash = "sha256-zMDpbJoOaKJ974Ln43JtY3f3WOq2dEmdgX9TubYdlow=";
  cargoBuildFlags = [
    "--package"
    "wasi-preview1-component-adapter"
  ];

  meta = {
    description = "A bridge for the wasip1 ABI to the wasip2 component model.";
    homepage = "https://wasmtime.dev";
    changelog = "https://github.com/bytecodealliance/wasmtime/releases";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
})
