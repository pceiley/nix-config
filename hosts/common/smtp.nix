# SMTP setup
{ config, ... }:

{
  environment.etc = {
    "aliases" = {
      text = ''
        root: peter@ceiley.com
        pceiley: peter@ceiley.com
      '';
      mode = "0644";
    };
  };

  programs.msmtp = {
    enable = true;
    extraConfig = ''
      account default
      auth on
      from alerts@ceiley.com
      user peter@ceiley.com
      eval echo -n 'host ' && cat ${config.sops.secrets."smtp/host".path}
      passwordeval cat ${config.sops.secrets."smtp/password".path}
      tls on
      tls_starttls off
      port 465
    '';

    defaults = {
      aliases = "/etc/aliases";
    };
  };

  sops.secrets = {
    "smtp/host" = {
      mode = "0440";
      group = config.users.groups.wheel.name;
    };
    "smtp/password" = {
      mode = "0440";
      group = config.users.groups.wheel.name;
    };
  };

}
