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

## Usage

```nix
{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-24.11";
    };

    zed-extensions = {
      url = "github:DuskSystems/nix-zed-extensions";
    };
  };
}
```

### Cache

We don't cache individual extension builds, but we do cache shared dependencies, so you won't need to re-compile LLVM/Rust.

```nix
nixConfig = {
  extra-substituters = [ "https://nix-zed-extensions.cachix.org" ];
  extra-trusted-public-keys = [ "nix-zed-extensions.cachix.org-1:+8tBcRBR66BzaedNWGDDG/hPA4g3SaEFJJDqrYNaawM=" ];
};
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
