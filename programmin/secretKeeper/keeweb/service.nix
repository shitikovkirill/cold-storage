{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.keeweb;
  proxyPass = "127.0.0.1:8443";

  certificate = (if cfg.https then
    { }
  else {
    sslCertificate = ./cert/keeweb.server.crt;
    sslCertificateKey = ./cert/keeweb.server.key;
  });

in {

  options = {
    services.keeweb = {
      enable = mkOption {
        default = false;
        description = ''
          Enable sentry.
        '';
      };

      domain = mkOption {
        type = types.str;
        example = "example.com";
        description = ''
          Domain
        '';
      };

      email = mkOption {
        type = types.str;
        example = "admin@example.com";
        description = ''
          Admin emale
        '';
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
    security.acme = {
      email = cfg.email;
      acceptTerms = true;
      #server = "https://acme-staging-v02.api.letsencrypt.org/directory";
    };

    services.nginx = {
      enable = true;
      statusPage = true;
      recommendedGzipSettings = true;
      virtualHosts."${cfg.domain}" = {
        enableACME = cfg.https;
        forceSSL = true;
        locations = { "/" = { proxyPass = "https://${proxyPass}"; }; };
      } // certificate;
    };

    virtualisation.oci-containers.containers = {
      keeweb = {
        image = "antelle/keeweb";
        ports = [ "8443:443" ];
      };
    };
  };
}
