{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.zed-editor-extensions;
  extensionsDir =
    if pkgs.stdenv.isDarwin then
      "Library/Application Support/Zed/extensions/installed"
    else
      "${config.xdg.dataHome}/zed/extensions/installed";
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
    home.file.${extensionsDir} = {
      recursive = true;
      source = pkgs.runCommand "zed-extensions-installed" { } ''
        mkdir -p $out
        ${lib.concatMapStringsSep "\n" (
          ext:
          assert builtins.pathExists "${ext}/share/zed/extensions" || throw "Invalid Zed extension passed to home-manager module: ${ext.pname}";
          ''
            ln -s ${ext}/share/zed/extensions/* $out
          ''
        ) cfg.packages}
      '';
    };
  };
}
