# Prowlarr - indexer aggregator for qBittorrent search, replacing the old
# nova3 search-plugin approach with a proper Torznab-based indexer manager.
#
# Runs inside the `mullvad` VPN namespace.
#
# Prowlarr has no native OIDC (unlike qui/papra) - gated by oauth2-proxy +
# Kanidm instead, same pattern qBittorrent itself used before qui replaced it.

{ config, pkgs, ... }:

let
  domain = "indexers.roastlan.net";
in
{
  services.prowlarr = {
    enable = true;
    openFirewall = false; # exposed via the VPN namespace portMapping instead

    # Per wiki.servarr.com/prowlarr/faq: External is "Configurable via
    # Config File Only" - deliberately absent from the UI dropdown, not a
    # version limitation. It fully disables Prowlarr's own auth checking
    # (unlike AuthenticationRequired=DisabledForLocalAddresses, which does a
    # per-request IP check that CVE-2026-30975 showed is spoofable via
    # headers in the Sonarr/Prowlarr codebase) - safe here specifically
    # because oauth2-proxy is the only path that can reach this service at
    # all (VPN-confined, no direct exposure).
    settings = {
      auth = {
        method = "External";
      };
    };
  };

  systemd.services.prowlarr.vpnConfinement = {
    enable = true;
    vpnNamespace = "mullvad";
  };

  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    clientID = "prowlarr";
    clientSecretFile = config.sops.secrets."prowlarr_oauth2_secret".path;
    cookie.secretFile = config.sops.secrets."prowlarr_oauth2_cookie".path;

    oidcIssuerUrl = "https://idm.roastlan.net/oauth2/openid/prowlarr";
    redirectURL = "https://${domain}/oauth2/callback";
    scope = "openid email profile groups";

    httpAddress = "127.0.0.1:4181"; # 4180 already used by qBittorrent's retired instance - keep this port free of collision
    upstream = "static://202";
    reverseProxy = true;
    setXauthrequest = true;
    email.domains = [ "*" ];
    trustedProxyIP = [ "127.0.0.1/32" ];

    nginx = {
      inherit domain;
      proxy = "http://127.0.0.1:4181";
      virtualHosts.${domain} = { };
    };

    extraConfig = {
      "code-challenge-method" = "S256";
      "oidc-groups-claim" = "groups";
      "allowed-group" = "qbittorrent.access@roastlan.net";
      "provider-display-name" = "Kanidm";
      "skip-provider-button" = "true";
      "insecure-oidc-allow-unverified-email" = "true";
      "whitelist-domain" = domain;
    };
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = "roastlan.net";
    extraConfig = ''
      proxy_buffer_size 16k;
      proxy_buffers 8 16k;
      proxy_busy_buffers_size 32k;
    '';
    locations."/" = {
      # Prowlarr's WebUI lives inside the mullvad namespace, reached across
      # the veth bridge exactly like qBittorrent's WebUI - see mullvad-vpn.nix
      # for the portMappings entry this depends on.
      proxyPass = "http://172.16.15.1:9696";
    };
  };

  sops.secrets = {
    "prowlarr_oauth2_secret" = { }; # also used by kanidm on superslice
    "prowlarr_oauth2_cookie" = { };
  };
}
