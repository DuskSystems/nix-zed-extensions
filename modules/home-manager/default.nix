{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.zed-editor-extensions;
in
{
  options.programs.zed-editor-extensions = {
    enable = lib.mkEnableOption "Nix-managed extensions for Zed editor";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "with pkgs.zed-extensions; [ nix ]";
      description = ''
        List of Zed extensions to install.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.packages != [ ]) {
    xdg.dataFile."zed/extensions/installed" = {
      recursive = true;
      source = pkgs.runCommand "zed-extensions-installed" { } ''
        mkdir -p $out
        ${lib.concatMapStringsSep "\n" (ext: ''
          ln -s ${ext}/share/zed/extensions/* $out
        '') cfg.packages}
      '';
    };
  };
}
