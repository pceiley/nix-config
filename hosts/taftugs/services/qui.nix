# qui - modern web frontend for qBittorrent (github.com/autobrr/qui).
# Talks to qBittorrent's existing WebUI API across the veth bridge at
# 172.16.15.1:58080 (see qbittorrent.nix, mullvad-vpn.nix) - qui itself needs
# no VPN confinement, it's only making local API calls.
#
# services.qui is too new to be in our pinned stable nixpkgs yet, so the
# module itself is borrowed from nixpkgs-unstable (disabledModules + import),
# same idea as pkgs.unstable.<pkg> but for a NixOS module rather than a
# package - the module and the package need to come from the same nixpkgs
# revision, so both are pinned to unstable together below.
#
# Unlike qBittorrent, qui has native OIDC support, so it authenticates
# directly against Kanidm rather than needing oauth2-proxy in front of it
# (which is why oauth2-proxy.nix has been retired - see nginx vhost below).
#
# The module's own `settings` is serialised straight into a Nix store path
# (world-readable), so anything secret must NOT go there. The module already
# handles the session secret correctly via secretFile + LoadCredential,
# staying out of settings/config.toml entirely; the OIDC client secret gets
# the identical treatment below, added onto the same systemd unit.

{ config, inputs, pkgs, lib, ... }:

let
  domain = "bt.roastlan.net";
in
{
  disabledModules = [ "services/torrent/qui.nix" ];
  imports = [ "${inputs.nixpkgs-unstable}/nixos/modules/services/torrent/qui.nix" ];

  sops.secrets."qui_session_secret" = { };
  sops.secrets."qui_oauth2_secret" = { }; # also used by kanidm on superslice

  services.qui = {
    enable = true;
    package = pkgs.unstable.qui;
    openFirewall = false;
    secretFile = config.sops.secrets."qui_session_secret".path;

    settings = {
      host = "127.0.0.1";
      port = 7476;

      # Non-secret OIDC settings only - the client secret is injected via
      # LoadCredential below, not here.
      oidcEnabled = true;
      oidcIssuer = "https://idm.roastlan.net/oauth2/openid/qui";
      oidcClientId = "qui";
      oidcRedirectUrl = "https://${domain}/api/auth/oidc/callback";
      oidcDisableBuiltInLogin = true; # SSO is the only entry point
    };
  };

  # LoadCredential isn't a list-merging option here (confirmed by nix
  # throwing a conflicting-definition error rather than auto-concatenating),
  # so this takes over the whole value with mkForce rather than trying to
  # add to the module's own definition - replicating its sessionSecret
  # credential alongside the new oidcClientSecret one. Environment, by
  # contrast, genuinely is list-typed (the module declares it as a list),
  # so a matching list here just merges in cleanly - no mkForce needed.
  systemd.services.qui.serviceConfig = {
    LoadCredential = lib.mkForce [
      "sessionSecret:${config.sops.secrets."qui_session_secret".path}"
      "oidcClientSecret:${config.sops.secrets."qui_oauth2_secret".path}"
    ];
    Environment = [
      "QUI__OIDC_CLIENT_SECRET_FILE=%d/oidcClientSecret"
    ];
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = "roastlan.net";
    locations."/" = {
      proxyPass = "http://127.0.0.1:7476";
    };
  };
}
