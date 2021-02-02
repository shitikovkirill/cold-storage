{ config, lib, pkgs, ... }:

let vars = import ../../../variables.nix;
in with vars; {
  imports = [ ./service.nix ];

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 ];
  };

  environment.systemPackages = with pkgs; [ docker ];

  services.sentry = {
    enable = true;
    domain = "sentry." + mainDomain;
    email = "test@gmail.com";
    secretKey = "xxxxxxxxxxx";
  };
}
