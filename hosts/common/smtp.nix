# SMTP setup

let
  passwordFile = "/persist/secrets/smtp.txt";
in
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
    accounts = {
      default = {
        auth = true;
        tls = true;
        from = "pgceiley@gmail.com";
        host = "smtp.gmail.com";
        user = "pgceiley@gmail.com";
        passwordeval = "cat ${passwordFile}";
      };
    };
    defaults = {
      aliases = "/etc/aliases";
    };
  };

}
