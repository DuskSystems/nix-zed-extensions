[![sync](https://github.com/DuskSystems/nix-zed-extensions/actions/workflows/sync.yml/badge.svg)](https://github.com/DuskSystems/nix-zed-extensions/actions/workflows/sync.yml)

# `nix-zed-extensions`

Nix expressions for Zed extensions.

## Status

- Over 400 extensions generated (see [extensions.json](extensions.json)).
- Daily sync from the Zed API.

But:

- No support for extensions in monorepos.
- No extension.json support.
- Requires a cargo lockfile for Rust extensions.
- Missing meta/licensing info.
- No automated building/testing of extensions.
- Requires a LLVM re-compilation due to WASI SDK usage.

## Usage

```nix
{
  inputs = {
    zed-extensions = {
      url = "github:DuskSystems/nix-zed-extensions";
    };
  };
}
```

### Overlay

```nix
nixpkgs.overlays = [
  zed-extensions.overlays.default
];
```

### Home Manager Module

This is a fork of the upstream module, except the `extensions` field now takes packages instead of strings.

```nix
home-manager.sharedModules = [
  zed-extensions.homeManagerModules.default
];
```

```nix
{
  pkgs,
}:

{
  programs.zed-editor-fork = {
    enable = true;
    extensions = with pkgs.zed-extensions; [
      nix
    ];
  };
}
```

## License

This project is licensed under the terms of the [GNU GPL v3.0](LICENSE), as it contains a re-implementation of [Zed's extension builder](https://github.com/zed-industries/zed/tree/main/crates/extension), which itself is licensed under the GNU GPL v3.0.
