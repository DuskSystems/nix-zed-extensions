{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "28.0";

  urls = {
    x86_64-linux = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-28/wasi-sdk-${version}-x86_64-linux.tar.gz";
      hash = "sha256-xF3GYb9q/v5z3SrkeuNyyfkNtdQRH+vITJzziZGjI10=";
    };

    aarch64-linux = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-28/wasi-sdk-${version}-arm64-linux.tar.gz";
      hash = "sha256-cu9vYFMIk2FRdy7nD6C/jcp3QrVUq7zW7WO4Aq4hsog=";
    };

    x86_64-darwin = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-28/wasi-sdk-${version}-x86_64-macos.tar.gz";
      hash = "sha256-JedAqCGYyLSqNE91OG6O+tZH98rgljgk4B9ZLujemfc=";
    };

    aarch64-darwin = {
      url = "https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-28/wasi-sdk-${version}-arm64-macos.tar.gz";
      hash = "sha256-CS0YWa1jON5AwW7gd5EC/xnAZ92GOtgWulr9i9jLcJ8=";
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
