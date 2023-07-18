# Wireguard Mullvad client config
#

{ config, ... }:

{
  networking.wg-quick.interfaces = {
    mullvadwg0 = {
      privateKeyFile = "/secrets/mullvadwg.txt";
      address = [ "10.66.113.54/32" ];
      #table = "off"; 
      table = "123"; 
      
      peers = [
        {
          publicKey = "4JpfHBvthTFOhCK0f5HAbzLXAVcB97uAkuLx7E8kqW0=";
          allowedIPs = [ "0.0.0.0/0" ];
          #allowedIPs = [ "10.66.113.54/32" ];
          endpoint = "146.70.200.2:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
