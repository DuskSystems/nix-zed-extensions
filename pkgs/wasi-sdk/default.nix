{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "27.0";

  urls = {
    x86_64-linux = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-27/wasi-sdk-${version}-x86_64-linux.tar.gz";
      hash = "sha256-t9TZRMiFA+TyHYSvB6wpPjRAsbYhC/1/544K/ZLCO8I=";
    };

    aarch64-linux = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-27/wasi-sdk-${version}-arm64-linux.tar.gz";
      hash = "sha256-TPTFU8RkDmPngEQhRvh9g/3/Vzf5iMBqbjsvAijjdmU=";
    };

    x86_64-darwin = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-27/wasi-sdk-${version}-x86_64-macos.tar.gz";
      hash = "sha256-Fj39R/mJsaaCdEwa4fDgmoP/XEu6ydzYVGkJq1TNpaE=";
    };

    aarch64-darwin = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-27/wasi-sdk-${version}-arm64-macos.tar.gz";
      hash = "sha256-BVw9wnZncsOOcaBdNT41wyLHssZFijaiaoNvmAilUPg=";
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
    license = with lib.licenses; [
      asl20
      llvm-exception
    ];
    platforms = lib.attrNames urls;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
