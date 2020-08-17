{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.devRedis;
  redmon = callPackage ./redmon {};
  user = "redis_admin";
  group = "redis_admin";
in {
  options = {
    services.devRedis = {
      enable = mkOption {
        default = false;
        description = ''
          Enable thinklocal web service.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.redis = {
      enable = true;
      openFirewall = true;
      bind = "0.0.0.0";
    };

    systemd.services.devRedisAdmin = {
      description = "Redis admin";
      after = [ "moodle-init.service" ];
      serviceConfig = {
        User = user;
        Group = group;
        ExecStart = "${redmon}/bin/redmon";
      };
    };

    users = {
      groups.${group} = { };
      users.${user} = {
        group = group;
        isSystemUser = true;
      };
    };
  };
}
