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

This will register all extensions as packages under `pkgs.zed-extensions`.

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

### Building Grammars Manually

Use the `buildZedGrammar` builder function.

```nix
{
  buildZedGrammar,
  fetchFromGitHub,
}:

buildZedGrammar (finalAttrs: {
  name = "nix";
  version = "b3cda619248e7dd0f216088bd152f59ce0bbe488";

  src = fetchFromGitHub {
    owner = "nix-community";
    repo = "tree-sitter-nix";
    rev = finalAttrs.version;
    hash = "sha256-Ib83CECi3hvm2GfeAJXIkapeN8rrpFQxCWWFFsIvB/Y=";
  };
})
```

```shell
result
└── share
    └── zed
        └── grammars
            └── nix.wasm
```

### Building Extensions Manually

Use the `buildZedExtension` and `buildZedRustExtension` builder functions.

```nix
{
  buildZedExtension,
  fetchFromGitHub,
}:

buildZedExtension (finalAttrs: {
  name = "catppuccin-icons";
  version = "1.19.0";

  src = fetchFromGitHub {
    owner = "catppuccin";
    repo = "zed-icons";
    rev = "v${finalAttrs.version}";
    hash = "sha256-1S4I9fJyShkrBUqGaF8BijyRJfBgVh32HLn1ZoNlnsU=";
  };
})
```

```shell
result
└── share
    └── zed
        └── extensions
            └── catppuccin-icons
                ├── extension.toml
                ├── icons
                │   └── ...
                └── icon_themes
                    └── catppuccin-icons.json
```

#### Rust

```nix
{
  buildZedRustExtension,
  fetchFromGitHub,
  zed-nix-grammar,
}:

buildZedRustExtension (finalAttrs: {
  name = "nix";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "zed-extensions";
    repo = "nix";
    rev = "v${finalAttrs.version}";
    hash = "sha256-2+Joy2kYqDK33E51pfUSYlLgWLFLLDrBlwJkPWyPUoo=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-F+qW+5SIiZNxdMSmtiwKj9j73Sd9uy5HZXGptcd3vSY=";

  grammars = [
    zed-nix-grammar
  ];
})
```

```shell
result
└── share
    └── zed
        └── extensions
            └── nix
                ├── extension.toml
                ├── extension.wasm
                ├── grammars
                │   └── nix.wasm
                └── languages
                    └── nix
                        ├── brackets.scm
                        ├── config.toml
                        ├── highlights.scm
                        ├── indents.scm
                        ├── injections.scm
                        └── outline.scm
```

## License

This project is licensed under the terms of the [GNU GPL v3.0](LICENSE), as it contains a re-implementation of [Zed's extension builder](https://github.com/zed-industries/zed/tree/main/crates/extension), which itself is licensed under the GNU GPL v3.0.
