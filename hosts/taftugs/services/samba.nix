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
    family = { };
    multimedia = { };
  };

  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = PURECHEESE
      server string = fileserver
      netbios name = fileserver
      security = user 
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      hosts allow = 192.168.10. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
    '';
    shares = {
      family = {
        path = "/net/share";
        browseable = "yes";
        "read only" = "yes";
        "guest ok" = "no";
        "create mask" = "0640";
        "directory mask" = "0750";
        "force user" = "pceiley";
        "force group" = "family";
      };
      multimedia = {
        path = "/net/media";
        browseable = "yes";
        "read only" = "yes";
        "guest ok" = "no";
        "create mask" = "0640";
        "directory mask" = "0750";
        "force user" = "pceiley";
        "force group" = "multimedia";
      };
    };
  };
}
