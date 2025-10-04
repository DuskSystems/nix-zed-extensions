#!/usr/bin/env bash

set -euxo pipefail

NIXPKGS=${1:-nixpkgs}

# CLI
nix build .#nix-zed-extensions \
  --quiet \
  --inputs-from . \
  --override-input nixpkgs $NIXPKGS

# Plain
nix build .#zed-extensions.catppuccin \
  --quiet \
  --inputs-from . \
  --override-input nixpkgs $NIXPKGS

tree result/share/zed/extensions/catppuccin
test -f result/share/zed/extensions/catppuccin/extension.toml
test -d result/share/zed/extensions/catppuccin/themes

# Rust
nix build .#zed-extensions.nix \
  --quiet \
  --inputs-from . \
  --override-input nixpkgs $NIXPKGS

tree result/share/zed/extensions/nix
test -f result/share/zed/extensions/nix/extension.toml
test -f result/share/zed/extensions/nix/extension.wasm
test -d result/share/zed/extensions/nix/grammars
test -d result/share/zed/extensions/nix/languages

# Monorepo Plain
nix build .#zed-extensions.aura-theme \
  --quiet \
  --inputs-from . \
  --override-input nixpkgs $NIXPKGS

tree result/share/zed/extensions/aura-theme
test -f result/share/zed/extensions/aura-theme/extension.toml
test -d result/share/zed/extensions/aura-theme/themes

# Monorepo Rust
nix build .#zed-extensions.html \
  --quiet \
  --inputs-from . \
  --override-input nixpkgs $NIXPKGS

tree result/share/zed/extensions/html
test -f result/share/zed/extensions/html/extension.toml
test -f result/share/zed/extensions/html/extension.wasm
test -d result/share/zed/extensions/html/grammars
test -d result/share/zed/extensions/html/languages

# Workspace Rust
nix build .#zed-extensions.deputy \
  --quiet \
  --inputs-from . \
  --override-input nixpkgs $NIXPKGS

tree result/share/zed/extensions/deputy
test -f result/share/zed/extensions/deputy/extension.toml
test -f result/share/zed/extensions/deputy/extension.wasm
