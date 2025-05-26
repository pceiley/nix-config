# SMTP setup

{ config, ... }:

{
  environment.etc = {
    "aliases" = {
      text = ''
        root: pgceiley@gmail.com
        pceiley: pgceiley@gmail.com
      '';
      mode = "0644";
    };
  };

  programs.msmtp = {
    enable = true;
    extraConfig = ''
      account default
      auth on
      eval echo -n 'from ' && cat ${config.sops.secrets."msmtp/email".path}
      eval echo -n 'user ' && cat ${config.sops.secrets."msmtp/email".path}
      eval echo -n 'host ' && cat ${config.sops.secrets."msmtp/host".path}
      passwordeval cat ${config.sops.secrets."msmtp/password".path}
      tls on
    '';

    defaults = {
      aliases = "/etc/aliases";
    };
  };

  sops.secrets = {
    "msmtp/email" = {
      mode = "0440";
      group = config.users.groups.wheel.name;
    };
    "msmtp/host" = {
      mode = "0440";
      group = config.users.groups.wheel.name;
    };
    "msmtp/password" = {
      mode = "0440";
      group = config.users.groups.wheel.name;
    };
  };

}
