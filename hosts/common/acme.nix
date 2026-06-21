# Let's Encrypt wildcard cert for *.roastlan.net via Cloudflare DNS-01. Each
# host obtains its own copy; cert files are readable by the nginx group. A host
# can add further certs with security.acme.certs."<name>" in its own config.

{ config, ... }:

{
  security.acme = {
    acceptTerms = true;
    defaults.email = "admin@roastlan.net";

    certs."roastlan.net" = {
      domain = "*.roastlan.net";
      dnsProvider = "cloudflare";
      environmentFile = config.sops.secrets.cloudflare_credentials.path;
      group = config.services.nginx.group;
    };
  };

  sops.secrets.cloudflare_credentials = {
    owner = "acme";
    group = "acme";
    mode = "0440";
  };
}
