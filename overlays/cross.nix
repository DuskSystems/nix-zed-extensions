final: prev: {
  # Setup custom 'wasm32-wasip1' target.
  # Don't touch 'wasi32', since it would trigger a Firefox re-compilation.
  pkgsCross = prev.pkgsCross // {
    wasm32-wasip1 = import prev.path {
      inherit (prev) system;

      crossSystem = prev.lib.systems.examples.wasi32 // {
        rust = {
          rustcTarget = "wasm32-wasip1";
        };
      };
    };
  };
}
