{
  config,
  lib,
  pkgs,
  ...
}:

# FORK: https://github.com/nix-community/home-manager/blob/master/modules/programs/zed-editor.nix

with lib;

let
  cfg = config.programs.zed-editor-fork;
  jsonFormat = pkgs.formats.json { };
in
{
  meta.maintainers = [ hm.maintainers.libewa ];

  options = {
    # TODO: add vscode option parity (configuring keybinds with nix etc.)
    programs.zed-editor-fork = {
      enable = mkEnableOption "Zed, the high performance, multiplayer code editor from the creators of Atom and Tree-sitter";

      package = mkPackageOption pkgs "zed-editor" { };

      extraPackages = mkOption {
        type = with types; listOf package;
        default = [ ];
        example = literalExpression "[ pkgs.nixd ]";
        description = "Extra packages available to Zed.";
      };

      userSettings = mkOption {
        type = jsonFormat.type;
        default = { };
        example = literalExpression ''
          {
            features = {
              copilot = false;
            };
            telemetry = {
              metrics = false;
            };
            vim_mode = false;
            ui_font_size = 16;
            buffer_font_size = 16;
          }
        '';
        description = ''
          Configuration written to Zed's {file}`settings.json`.
        '';
      };

      userKeymaps = mkOption {
        type = jsonFormat.type;
        default = { };
        example = literalExpression ''
          [
            {
              context = "Workspace";
              bindings = {
                ctrl-shift-t = "workspace::NewTerminal";
              };
            };
          ]
        '';
        description = ''
          Configuration written to Zed's {file}`keymap.json`.
        '';
      };

      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        example = lib.literalExpression "with pkgs.zed-extensions; [ nix ]";
        description = ''
          List of Zed extensions to install.
        '';
      };

      installRemoteServer = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          Whether to symlink the Zed's remote server binary to the expected
          location. This allows remotely connecting to this system from a
          distant Zed client.

          For more information, consult the
          ["Remote Server" section](https://wiki.nixos.org/wiki/Zed#Remote_Server)
          in the wiki.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      if cfg.extraPackages != [ ] then
        [
          (pkgs.symlinkJoin {
            name = "${lib.getName cfg.package}-wrapped-${lib.getVersion cfg.package}";
            paths = [ cfg.package ];
            preferLocalBuild = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/zeditor \
                --suffix PATH : ${lib.makeBinPath cfg.extraPackages}
            '';
          })
        ]
      else
        [ cfg.package ];

    home.file = mkIf (cfg.installRemoteServer && (cfg.package ? remote_server)) (
      let
        inherit (cfg.package) version remote_server;
        binaryName = "zed-remote-server-stable-${version}";
      in
      {
        ".zed_server/${binaryName}".source = lib.getExe' remote_server binaryName;
      }
    );

    xdg.configFile."zed/settings.json" = (
      mkIf (cfg.userSettings != { }) {
        source = jsonFormat.generate "zed-user-settings" cfg.userSettings;
      }
    );

    xdg.dataFile."zed" = lib.mkIf (cfg.extensions != [ ]) {
      recursive = true;
      source = pkgs.symlinkJoin {
        name = "zed-extensions-combined";
        paths = cfg.extensions;
      };
    };

    xdg.configFile."zed/keymap.json" = (
      mkIf (cfg.userKeymaps != { }) {
        source = jsonFormat.generate "zed-user-keymaps" cfg.userKeymaps;
      }
    );
  };
}
