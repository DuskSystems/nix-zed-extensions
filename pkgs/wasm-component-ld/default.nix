{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "wasm-component-ld";
  version = "0.5.12";

  src = fetchFromGitHub {
    owner = "bytecodealliance";
    repo = "wasm-component-ld";
    rev = "v${finalAttrs.version}";
    hash = "sha256-ezmzr5l0ucQ8H4eVXNA2I/BBb8wlvKimKxsk4W6FPks=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-OB9yNPjwdUXGn9G9PYuLG0DernOxaXAowCkwiOSuySQ=";

  doCheck = false;

  meta = {
    description = "Command line linker for creating WebAssembly components.";
    homepage = "https://github.com/bytecodealliance/wasm-component-ld";
    license = [
      lib.licenses.asl20
      lib.licenses.llvm-exception
      lib.licenses.mit
    ];
    platforms = lib.platforms.all;
  };
})
