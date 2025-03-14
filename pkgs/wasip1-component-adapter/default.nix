{
  lib,
  pkgsCross,
  fetchFromGitHub,
  llvmPackages,
}:

pkgsCross.wasm32-wasip1.rustPlatform.buildRustPackage rec {
  pname = "wasip1-component-adapter";
  version = "30.0.2";

  src = fetchFromGitHub {
    owner = "bytecodealliance";
    repo = "wasmtime";
    rev = "v${version}";
    hash = "sha256-crVetjCSdwMotVvlIB2fJIFDrGrRE72LmRRw9DwYmyc=";
    fetchSubmodules = true;
  };

  RUSTFLAGS = "-C linker=${llvmPackages.lld}/bin/lld";

  useFetchCargoVendor = true;
  cargoHash = "sha256-YupZr9jturuiFICubrXeOpAeFRvvdX4iRrarBkGL2s0=";
  cargoBuildFlags = [
    "--package"
    "wasi-preview1-component-adapter"
  ];

  meta = with lib; {
    description = "A bridge for the wasip1 ABI to the wasip2 component model.";
    homepage = "https://wasmtime.dev";
    changelog = "https://github.com/bytecodealliance/wasmtime/releases";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}
