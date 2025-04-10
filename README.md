[![sync](https://github.com/DuskSystems/nix-zed-extensions/actions/workflows/sync.yml/badge.svg)](https://github.com/DuskSystems/nix-zed-extensions/actions/workflows/sync.yml)

# `nix-zed-extensions`

Nix expressions for Zed extensions.

- Over 400 extensions generated (see [extensions.json](extensions.json)).
- Daily sync from the Zed API.

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

A `home-manager` module that allows you to install extensions.

Use it alongside your existing `zed-editor` config.

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
  programs.zed-editor = {
    ...
  };

  programs.zed-editor-extensions = {
    enable = true;
    packages = with pkgs.zed-extensions; [
      nix
    ];
  };
}
```

## License

This project is licensed under the terms of the [GNU GPL v3.0](LICENSE), as it contains a re-implementation of [Zed's extension builder](https://github.com/zed-industries/zed/tree/main/crates/extension), which itself is licensed under the GNU GPL v3.0.
