{
  lib,
  rustPlatform,
  makeWrapper,
  fetch-cargo-vendor-util,
  nix-prefetch-git,
}:

rustPlatform.buildRustPackage {
  name = "nix-zed-extensions";
  version = "0.0.0";

  src = ../../.;

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    fetch-cargo-vendor-util
    nix-prefetch-git
  ];

  cargoLock = {
    lockFile = ../../Cargo.lock;
  };

  postInstall = ''
    wrapProgram $out/bin/nix-zed-extensions \
      --prefix PATH : ${
        lib.makeBinPath [
          fetch-cargo-vendor-util
          nix-prefetch-git
        ]
      }
  '';

  meta = {
    homepage = "https://github.com/DuskSystems/nix-zed-extensions";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
    mainProgram = "nix-zed-extensions";
  };
}
