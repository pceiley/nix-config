# oauth2-proxy: Kanidm SSO in front of the qBittorrent WebUI.
#
# qBittorrent has no native OIDC, so oauth2-proxy (host namespace) does the
# Kanidm OIDC dance and nginx gates the vhost via auth_request. Only after a
# valid Kanidm login does nginx proxy through to the WebUI, which lives in the
# `mullvad` namespace and is reached across the veth bridge at 192.168.15.1.
# qBittorrent's own auth is bypassed for the host's bridge source (192.168.15.5)
# via its WebUI subnet whitelist (set in the qBittorrent UI, not here).

{ config, ... }:

let
  domain = "bt.roastlan.net";
in
{
  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    clientID = "qbittorrent";
    clientSecretFile = config.sops.secrets."qbittorrent_oauth2_secret".path;
    cookie.secretFile = config.sops.secrets."qbittorrent_oauth2_cookie".path;

    oidcIssuerUrl = "https://idm.roastlan.net/oauth2/openid/qbittorrent";
    redirectURL = "https://${domain}/oauth2/callback";
    scope = "openid email profile groups";

    httpAddress = "127.0.0.1:4180";
    upstream = "static://202";          # unused; nginx does the proxying
    reverseProxy = true;                # trust X-Forwarded-* from nginx
    setXauthrequest = true;
    email.domains = [ "*" ];            # access is gated by kanidm group instead
    trustedProxyIP = [ "127.0.0.1/32" ];

    nginx = {
      inherit domain;
      proxy = "http://127.0.0.1:4180";
      virtualHosts.${domain} = { };
    };

    extraConfig = {
      "code-challenge-method" = "S256";   # kanidm requires PKCE
      "oidc-groups-claim" = "groups";
      "allowed-group" = "qbittorrent.access@roastlan.net";
      "provider-display-name" = "Kanidm";
      "skip-provider-button" = "true";
      # kanidm may not flag email_verified; don't reject on it.
      "insecure-oidc-allow-unverified-email" = "true";
    };
  };

  # protected vhost: auth_request is injected by the oauth2-proxy nginx module;
  # on success we proxy to the WebUI across the VPN bridge.
  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = "roastlan.net";
    locations."/" = {
      proxyPass = "http://192.168.15.1:58080";
    };
  };

  sops.secrets = {
    "qbittorrent_oauth2_secret" = { };  # also used by kanidm on superslice
    "qbittorrent_oauth2_cookie" = { };
  };
}
