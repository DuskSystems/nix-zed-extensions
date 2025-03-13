{
  lib,
  clangStdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  python3,
  git,
  wasm-component-ld,
}:

clangStdenv.mkDerivation {
  name = "wasi-sdk";
  version = "21.0";

  src = fetchFromGitHub {
    owner = "WebAssembly";
    repo = "wasi-sdk";
    tag = "wasi-sdk-25";
    hash = "sha256-uM4iO4nY99rw7PUzwTGTQGpyvKTT15Co0afdDxpRfa4=";
    deepClone = true;
    fetchSubmodules = true;
  };

  patches = [
    ./patches/wasm-component-ld.patch
  ];

  postPatch = ''
    patchShebangs .
  '';

  nativeBuildInputs = [
    cmake
    ninja
    python3
    git
    wasm-component-ld
  ];

  dontConfigure = true;

  buildPhase = ''
    cmake -G Ninja -B build/toolchain -S . \
      -DWASI_SDK_BUILD_TOOLCHAIN=ON \
      -DCMAKE_INSTALL_PREFIX=$out \

    cmake --build build/toolchain --target install

    cmake -G Ninja -B build/sysroot -S . \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_TOOLCHAIN_FILE=$out/share/cmake/wasi-sdk.cmake \
      -DCMAKE_C_COMPILER_WORKS=ON \
      -DCMAKE_CXX_COMPILER_WORKS=ON

    cmake --build build/sysroot --target install
  '';

  installPhase = ''
    mkdir -p $out/bin
    ln -s ${wasm-component-ld}/bin/wasm-component-ld $out/bin/wasm-component-ld

    LLVM_MAJOR=$(python3 version.py llvm-major)
    mkdir -p $out/lib/clang/$LLVM_MAJOR
    ln -s $out/clang-resource-dir/lib $out/lib/clang/$LLVM_MAJOR/lib
  '';

  meta = {
    description = "WASI SDK for compiling C/C++ to WebAssembly.";
    homepage = "https://github.com/WebAssembly/wasi-sdk";
    license = lib.licenses.asl20-llvm;
    platforms = lib.platforms.all;
  };
}
