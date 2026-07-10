# Homelab monitoring stack: prometheus (:9090) + alertmanager (:9093) +
# grafana (:3000), all bound to localhost and reverse-proxied with TLS at
# {grafana,prometheus,alertmanager}.roastlan.net. prometheus/alertmanager have
# no auth, so keep them LAN-only. Needs DNS A records for those three names ->
# 192.168.5.5 and the grafana_admin_password secrets.

{ config, pkgs, ... }:

let
  # Alertmanager dials SMTP itself, so it reuses the email provider relay rather
  # than the msmtp binary.
  smtpSmarthost = "smtp.fastmail.com:587";
  smtpFrom      = "alerts@ceiley.com";
  smtpLogin     = "peter@ceiley.com";
  alertTo       = "peter@ceiley.com";
in
{
  # Prometheus
  services.prometheus = {
    enable = true;
    port = 9090;
    listenAddress = "127.0.0.1";
    webExternalUrl = "https://prometheus.roastlan.net";

    globalConfig.scrape_interval = "15s";

    alertmanagers = [
      { static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ]; }
    ];

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "127.0.0.1:9100" ];
            labels.instance = "superslice";
          }
          {
            targets = [ "192.168.6.3:9100" ];
            labels.instance = "taftugs";
          }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:9090" ];
            labels.instance = "superslice";
          }
        ];
      }
    ];

    rules = [
      ''
        groups:
          - name: homelab
            rules:
              - alert: InstanceDown
                expr: up == 0
                for: 5m
                labels:
                  severity: critical
                annotations:
                  summary: "{{ $labels.instance }} ({{ $labels.job }}) is unreachable"

              - alert: FilesystemFillingUp
                expr: |
                  (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|ramfs"}
                    / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|ramfs"}) < 0.10
                for: 15m
                labels:
                  severity: warning
                annotations:
                  summary: "Low disk space on {{ $labels.instance }} {{ $labels.mountpoint }}"

              - alert: SystemdUnitFailed
                expr: node_systemd_unit_state{state="failed"} == 1
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: "systemd unit {{ $labels.name }} failed on {{ $labels.instance }}"

              - alert: ResticBackupStale
                expr: |
                  time() - restic_backup_last_snapshot_timestamp_seconds > 26 * 3600
                for: 30m
                labels:
                  severity: warning
                annotations:
                  summary: "restic repo {{ $labels.repo }} has no snapshot in >26h"

              - alert: ResticRepoUnreachable
                expr: restic_backup_query_success == 0
                for: 2h
                labels:
                  severity: warning
                annotations:
                  summary: "restic repo {{ $labels.repo }} query failing (unreachable/auth)"
      ''
    ];
  };

  # Alertmanager
  services.prometheus.alertmanager = {
    enable = true;
    port = 9093;
    listenAddress = "127.0.0.1";
    webExternalUrl = "https://alertmanager.roastlan.net";

    # Off because amtool can't read smtp_auth_password_file at build time.
    checkConfig = false;

    configuration = {
      global = {
        smtp_smarthost = smtpSmarthost;
        smtp_from = smtpFrom;
        smtp_auth_username = smtpLogin;
        smtp_auth_password_file = "/run/credentials/alertmanager.service/smtp_password";
        smtp_require_tls = true;
      };

      route = {
        receiver = "email";
        group_by = [ "alertname" "instance" ];
        group_wait = "30s";
        group_interval = "5m";
        repeat_interval = "4h";
      };

      receivers = [
        {
          name = "email";
          email_configs = [
            {
              to = alertTo;
              send_resolved = true;
            }
          ];
        }
      ];
    };
  };

  systemd.services.alertmanager.serviceConfig.LoadCredential =
    [ "smtp_password:${config.sops.secrets."smtp/password".path}" ];
  # Grafana
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        domain = "grafana.roastlan.net";
        root_url = "https://grafana.roastlan.net/";
      };

      security.admin_password = "$__file{${config.sops.secrets.grafana_admin_password.path}}";
      # Keep this value stable
      security.secret_key = "$__file{${config.sops.secrets.grafana_secret_key.path}}";
      analytics.reporting_enabled = false;

      "auth.generic_oauth" = {
        enabled = true;
        name = "Kanidm";
        client_id = "grafana";
        client_secret = "$__file{${config.sops.secrets."grafana_oauth2_secret".path}}";
        scopes = "openid email profile groups";
        auth_url = "https://idm.roastlan.net/ui/oauth2";
        token_url = "https://idm.roastlan.net/oauth2/token";
        api_url = "https://idm.roastlan.net/oauth2/openid/grafana/userinfo";
        use_pkce = true;
        allow_sign_up = true;
        login_attribute_path = "preferred_username";
        email_attribute_path = "email";
        # admins -> Admin, everyone else with access -> Viewer
        role_attribute_path = "contains(groups[*], 'grafana.admins@roastlan.net') && 'Admin' || 'Viewer'";
      };

    };

    provision = {
      enable = true;

      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            uid = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:9090";
            isDefault = true;
          }
        ];
      };

      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "homelab";
            type = "file";
            options.path = ./monitoring/dashboards;
            options.foldersFromFilesStructure = false;
          }
        ];
      };
    };
  };

  # nginx reverse proxy (TLS)
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."grafana.roastlan.net" = {
      forceSSL = true;
      useACMEHost = "roastlan.net";
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000";
        proxyWebsockets = true;
      };
    };

    virtualHosts."prometheus.roastlan.net" = {
      forceSSL = true;
      useACMEHost = "roastlan.net";
      locations."/" = {
        proxyPass = "http://127.0.0.1:9090";
      };
    };

    virtualHosts."alertmanager.roastlan.net" = {
      forceSSL = true;
      useACMEHost = "roastlan.net";
      locations."/" = {
        proxyPass = "http://127.0.0.1:9093";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Secrets (cloudflare_credentials + the *.roastlan.net cert live in common/acme.nix)
  sops.secrets.grafana_admin_password = {
    owner = "grafana";
    mode = "0400";
  };

  sops.secrets.grafana_secret_key = {
    owner = "grafana";
    mode = "0400";
  };

}
