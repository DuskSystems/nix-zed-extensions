final: prev: {
  # Setup custom 'wasm32-wasip2' target.
  # Dont touch 'wasi32', since it would trigger a Firefox recompilation.
  pkgsCross = prev.pkgsCross // {
    wasm32-wasip2 = import prev.path {
      inherit (prev) system;

      crossSystem = prev.lib.systems.examples.wasi32 // {
        rust = {
          rustcTarget = "wasm32-wasip2";
        };
      };
    };
  };
}
