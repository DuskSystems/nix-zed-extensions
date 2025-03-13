{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "wasm-component-ld";
  version = "0.5.12";

  src = fetchFromGitHub {
    owner = "bytecodealliance";
    repo = "wasm-component-ld";
    rev = "v${version}";
    hash = "sha256-ezmzr5l0ucQ8H4eVXNA2I/BBb8wlvKimKxsk4W6FPks=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-OB9yNPjwdUXGn9G9PYuLG0DernOxaXAowCkwiOSuySQ=";

  doCheck = false;

  meta = {
    description = "Command line linker for creating WebAssembly components.";
    homepage = "https://github.com/bytecodealliance/wasm-component-ld";
    license = [
      lib.licenses.asl20-llvm
      lib.licenses.asl20
      lib.licenses.mit
    ];
    platforms = lib.platforms.all;
  };
}
