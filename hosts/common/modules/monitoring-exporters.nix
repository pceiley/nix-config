# Prometheus exporters that run on every host we want to monitor.
#
# Just the node exporter for now (:9100). On top of the default collectors
# (cpu, meminfo, diskstats, filesystem, netdev, zfs, ...) we turn on the
# `systemd` collector so a failed unit shows up as a metric and can drive a
# Grafana panel / alert. The `zfs` collector ships in the default set and
# simply stays idle on hosts without ZFS, so taftugs' `data` pool is covered
# without any host-specific tweak.
#
# Networking note: the Prometheus server runs on superslice (subnet
# 192.168.5.0/24) while taftugs sits on 192.168.10.0/24. The scrape
# therefore crosses subnets, so pea-gw must permit
#     192.168.5.5  ->  <host>:9100

{ ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" ];
  };

  networking.firewall.allowedTCPPorts = [ 9100 ];
}
