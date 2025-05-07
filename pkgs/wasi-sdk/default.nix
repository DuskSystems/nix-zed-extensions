{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "25.0";

  urls = {
    x86_64-linux = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-25/wasi-sdk-${version}-x86_64-linux.tar.gz";
      hash = "sha256-UmQN3hNZm/EnqVSZ5h1tZAJWEZRW0a+Il6tnJbzz2Jw=";
    };

    aarch64-linux = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-25/wasi-sdk-${version}-arm64-linux.tar.gz";
      hash = "sha256-R/zK2LJJjyI54F4RFcP/xlK/N+feL4j7ZLLWY8l2zi0=";
    };

    x86_64-darwin = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-25/wasi-sdk-${version}-x86_64-macos.tar.gz";
      hash = "sha256-VeP/P+4aFWeKFu7MugEpJ2yfa+SBvJwoPn+fZb8FXBE=";
    };

    aarch64-darwin = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-25/wasi-sdk-${version}-arm64-macos.tar.gz";
      hash = "sha256-4eUp6iJrHbC0MDJ4Cd6ukka1gPo8rjLTHILf53AjNYc=";
    };
  };
in
stdenv.mkDerivation {
  pname = "wasi-sdk";
  inherit version;

  src = fetchurl urls.${stdenv.hostPlatform.system};

  nativeBuildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc
    autoPatchelfHook
  ];

  installPhase = ''
    mkdir -p $out
    cp -r . $out
  '';

  dontStrip = true;

  meta = {
    description = "WASI SDK for compiling C/C++ to WebAssembly.";
    homepage = "https://github.com/WebAssembly/wasi-sdk";
    # See:
    # 1. https://github.com/NixOS/nixpkgs/pull/217867
    # 2. https://github.com/NixOS/nixpkgs/pull/390638
    # TLDR: nixpkgs 23.05 introduced asl20-llvm, then 25.05 reverted back to use llvm-exception.
    license =
      if (lib.versions.majorMinor lib.version) == "24.11" then
        [
          lib.licenses.asl20-llvm
        ]
      else
        [
          lib.licenses.asl20
          lib.licenses.llvm-exception
        ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
