# Samba server configuration
{
  services.samba.openFirewall = true;

  services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  networking.firewall.allowedTCPPorts = [
    5357 # wsdd
  ];
  networking.firewall.allowedUDPPorts = [
    3702 # wsdd
  ];

  # Set up groups for samba shares
  users.groups = {
    family.gid = 8888;
    multimedia.gid = 8889;
  };

  services.samba = {
    enable = true;
    settings = {
      global = {
        workgroup = "PURECHEESE";
        "server string" = "fileserver";
        "netbios name" = "fileserver";
        security = "user";
        "hosts allow" = "192.168.10. 192.168.52. 192.168.40. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };

      family = {
        path = "/data/family";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0660";
        "directory mask" = "2770";
        #"force user" = "pceiley";
        "force group" = "family";
      };

      multimedia = {
        path = "/data/multimedia";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0664";
        "directory mask" = "2775";
        #"force user" = "pceiley";
        "force group" = "multimedia";
      };
    };
  };
}
