# Mullvad VPN confined to a network namespace (Maroka-chan/VPN-Confinement).
#
# Only systemd services that explicitly opt in (see qbittorrent.nix) run inside
# this namespace. Everything else on the host keeps using the normal default
# route. The namespace contains ONLY the wireguard interface, so a confined
# service cannot reach the clear internet even if the tunnel drops (fail-closed).
#
# The full wg config (key + peer + endpoint + DNS) lives encrypted in sops as
# `wireguard_wg0_conf`. NOTE: VPN-Confinement uses `wg setconf`, so wg-quick-only
# fields (Table/PostUp/PostDown) are ignored and a `DNS =` line is REQUIRED
# (the namespace resolves DNS through the tunnel and drops everything else).
{ config, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.wireguard-tools ];

  sops.secrets.wireguard_wg0_conf = {
    mode = "0400"; # read by the root-run namespace bring-up service
  };

  vpnNamespaces.mullvad = {
    enable = true;
    wireguardConfigFile = config.sops.secrets.wireguard_wg0_conf.path;
    # WebUI is no longer exposed to the LAN; nginx reaches it across the
    # veth bridge (192.168.15.1) and SSO is the only entry point.
    # # LAN subnet(s) allowed to reach mapped ports (add VLANs as needed).
    # accessibleFrom = [ "192.168.10.0/24" "192.168.40.0/24" "192.168.52.0/24" ];
    # # Expose the qBittorrent WebUI from the host: host:58080 -> namespace:58080.
    # portMappings = [ { from = 58080; to = 58080; } ];
  };
}
