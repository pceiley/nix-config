# Wireguard client setup for Mullvad
#
# Device: Steady Pug
{ pkgs, ... }:
let
  wgip = "10.66.113.54/32";
  tableId = "1007";
in
{
  networking.wg-quick.interfaces = {
    wg0 = {
      address = [ wgip ];
      #dns = [ "10.64.0.1" ];
      privateKeyFile = "/persist/secrets/wireguard-wg0.txt";

      #${pkgs.iproute2}/bin/ip route add ${wgip} dev wg0 src ${wgip} table ${tableId}
      # Configure routing such that
      # only apps that bind to the interface will use the tunnel
      table = "off";
      postUp = ''
        ${pkgs.iproute2}/bin/ip route add default dev wg0 table ${tableId}
        ${pkgs.iproute2}/bin/ip rule add from ${wgip} table ${tableId}
        ${pkgs.iproute2}/bin/ip rule add to ${wgip} table ${tableId}
      '';
      postDown = ''
        ${pkgs.iproute2}/bin/ip route delete default table ${tableId}
        ${pkgs.iproute2}/bin/ip rule delete from ${wgip} table ${tableId}
        ${pkgs.iproute2}/bin/ip rule delete to ${wgip} table ${tableId}
      '';

      peers = [
        {
          publicKey = "4JpfHBvthTFOhCK0f5HAbzLXAVcB97uAkuLx7E8kqW0=";
          #allowedIPs = [ wgip ];
          allowedIPs = [ "0.0.0.0/0" ];
          # Set this to the server IP and port.
          endpoint = "146.70.200.2:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };

}
