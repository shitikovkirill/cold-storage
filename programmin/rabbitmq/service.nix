{ config, lib, pkgs, ... }:
with lib;
let cfg = config.services.devRabbitmq;
in {
  options = {
    services.devRabbitmq = {
      enable = mkOption {
        default = false;
        description = ''
          Enable thinklocal web service.
        '';
      };

      domain = mkOption {
        type = types.str;
        description = "domain";
      };

      https = mkOption {
        default = false;
        description = ''
          Enable https.
        '';
      };
    };
  };

  config = mkIf cfg.enable {

    networking = {
      firewall = {
        enable = true;
        allowedTCPPorts = [ 80 443 5672 ];
      };
    };

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;

      upstreams = {
        "rabbitmq_server" = { servers = { "127.0.0.1:15672" = { }; }; };
      };

      virtualHosts = {
        "${cfg.domain}" = {
          enableACME = cfg.https;
          forceSSL = cfg.https;
          locations = {
            "/" = { proxyPass = "http://rabbitmq_server"; };
          };
        };
      };
    };

    services.rabbitmq = {
      enable = true;
      listenAddress = "0.0.0.0";
      plugins = [ "rabbitmq_management" "rabbitmq_prometheus" ];
      #config = "[{rabbit, [{loopback_users, []}]}].";
    };
  };
}
