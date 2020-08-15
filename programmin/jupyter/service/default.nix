{ config, lib, pkgs, ... }:

with lib;
let
  ipytest = pkgs.callPackage ./pkgs/ipytest.nix { };

  cfg = config.services.jupyterlab;

  jupyterWith = let
    jupyterWithSrc = pkgs.fetchFromGitHub {
      owner = "tweag";
      repo = "jupyterWith";
      rev = "1176b9e8d173f2d2789705ad55c7b53a06155e0f";
      sha256 = "0pgqk7bs89d1spjs2kvwgcnqfil6nsawfwiivrm4s61s9lzd78c0";
    };
    haskellOverlay = import "${jupyterWithSrc}/nix/haskell-overlay.nix";
    pythonOverlay = import "${jupyterWithSrc}/nix/python-overlay.nix";
  in import jupyterWithSrc {
    pkgs = pkgs.appendOverlays [ pythonOverlay haskellOverlay ];
  };

  iPython = jupyterWith.kernels.iPythonWith {
    name = "python";
    packages = p: with p; [ numpy ];
  };

  iPythonAsync = jupyterWith.kernels.iPythonWith {
    name = "python_async";
    packages = p: with p; [ ipdb asynctest ipytest ];
  };

  iPythonSql = jupyterWith.kernels.iPythonWith {
    name = "sqlalchemy";
    packages = p: with p; [ ipdb sqlalchemy ];
  };

  jupyterlabPackage = lib.makeOverridable jupyterWith.jupyterlabWith {
    kernels = [ iPythonAsync iPythonSql ];
  };

in {
  meta.maintainers = with maintainers; [ ];

  options.services.jupyterlab = {
    enable = mkEnableOption "JupyterLab server";

    package = mkOption {
      default = jupyterlabPackage;
      type = types.package;
      defaultText = "jupyterWith.jupyterlabWith {}";
      example = "jupyterWith.jupyterlabWith { kernels = [ ipython ]; }";
    };

    ip = mkOption {
      type = types.str;
      default = "localhost";
      description = ''
        IP address Jupyterlab will be listening on.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 8888;
      description = ''
        Port number Jupyterlab will be listening on.
      '';
    };

    notebookDir = mkOption {
      type = types.str;
      default = "/var/lib/jupyterlab";
      description = ''
        Root directory for notebooks.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "jupyterlab";
      description = ''
        Name of the user used to run the jupyterlab service.
        For security reason, jupyterlab should really not be run as root.
        If not set (jupyterlab), the service will create a jupyterlab user with appropriate settings.
      '';
      example = "me";
    };

    group = mkOption {
      type = types.str;
      default = "jupyterlab";
      description = ''
        Name of the group used to run the jupyterlab service.
        Use this if you want to create a group of users that are able to view the notebook directory's content.
      '';
      example = "users";
    };

    password = mkOption {
      type = types.str;
      description = ''
        Password to use with notebook.
        Can be generated using:
          In [1]: from notebook.auth import passwd
          In [2]: passwd('test')
          Out[2]: 'sha1:1b961dc713fb:88483270a63e57d18d43cf337e629539de1436ba'
          NOTE: you need to keep the single quote inside the nix string.
        Or you can use a python oneliner:
          "open('/path/secret_file', 'r', encoding='utf8').read().strip()"
        It will be interpreted at the end of the notebookConfig.
      '';
      example = [
        "'sha1:1b961dc713fb:88483270a63e57d18d43cf337e629539de1436ba'"
        "open('/path/secret_file', 'r', encoding='utf8').read().strip()"
      ];
    };

    notebookConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Raw jupyterlab config.
      '';
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Additional command line flags to be passed to jupyter-lab.
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      systemd.services.jupyterlab = {
        description = "JupyterLab server";

        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        path = [ pkgs.bash ];

        serviceConfig = {
          Restart = "always";
          RestartSec = 10;
          ExecStart = let
            notebookConfigFile = pkgs.writeText "jupyter_notebook_config.py" ''
              ${cfg.notebookConfig}
              c.NotebookApp.password = ${cfg.password}
            '';
            args = [
              "--no-browser"
              "--ip=${cfg.ip}"
              "--port=${toString cfg.port}"
              "--port-retries=0"
              "--notebook-dir=${cfg.notebookDir}"
              "--NotebookApp.config_file=${notebookConfigFile}"
            ] ++ cfg.extraFlags;
          in "${cfg.package}/bin/jupyter-lab ${
            concatMapStringsSep " \\\n" escapeShellArg args
          }";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = "~";
        };
      };
    })

    (mkIf (cfg.enable && (cfg.group == "jupyterlab")) {
      users.groups.jupyterlab = { };
    })
    (mkIf (cfg.enable && (cfg.user == "jupyterlab")) {
      users.extraUsers.jupyterlab = {
        extraGroups = [ cfg.group ];
        home = "/var/lib/jupyterlab";
        createHome = true;
        useDefaultShell = true; # needed so that the user can start a terminal.
      };
    })
  ];
}