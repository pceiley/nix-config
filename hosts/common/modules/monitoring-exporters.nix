# node exporter (:9100) for every monitored host, with a firewall rule that
# only lets the Prometheus host scrape it.
#
# The source match requires the nftables backend, enabled per-host via
# networking.nftables.enable (see each host's default.nix); without it the rule
# below is ignored. iptables-using services (VPN-Confinement on taftugs, libvirt
# on superslice) keep working via iptables-nft. IPv4-only; the cross-subnet
# scrape from superslice is routed (not NATed) so taftugs sees the real source.

{ ... }:

let
  prometheusHost = "192.168.6.4"; # superslice
in
{
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  networking.firewall.extraInputRules = ''
    ip saddr ${prometheusHost} tcp dport 9100 accept
  '';
}
