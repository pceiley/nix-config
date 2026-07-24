# Jellyfin

{ pkgs, config, ... }:

let
  address = "jellyfin.roastlan.net";
in
{

  systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";
  # GPU access for hardware transcoding (renderD128 is root:render 660) —
  # same pattern used for the immich user in ./immich.nix.
  users.users.jellyfin.extraGroups = [ "video" "render" ];

  services.jellyfin = {
    enable = true;
    # openFirewall = true;
    package = pkgs.unstable.jellyfin;

    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
      device = "/dev/dri/renderD128";
    };
    forceEncodingConfig = true;
    transcoding = {
      enableToneMapping = true;
      throttleTranscoding = false;
      enableHardwareEncoding = true;
      # Off, not just for HEVC: this NixOS module drives both the H264 and
      # HEVC low-power XML flags off this one option, and vainfo confirms
      # this driver/hardware has no VAEntrypointEncSliceLP for HEVCMain at
      # all (only regular EncSlice) — LP forced ffmpeg to demand an
      # entrypoint that doesn't exist, causing HEVC transcodes to fail with
      # "No usable encoding entrypoint found for profile VAProfileHEVCMain".
      # H264 does have EncSliceLP available, but there's no way to enable
      # it for H264 alone through this option.
      enableIntelLowPowerEncoding = false;
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        hevc10bit = true; # Main10 — supported on Gen9.5 (Coffee Lake)
        mpeg2 = true;
        vc1 = true;
        vp8 = true;
        vp9 = true;
        # av1 = false — i5-8500's UHD 630 (Gen9.5) has no AV1 decode block;
        # that arrived with Ice Lake (Gen11).
      };
      hardwareEncodingCodecs = {
        hevc = true;
        # av1 = false — no AV1 encode until Arc/Xe (Gen12.7+).
      };
    };
  };

  services.nginx = {
    virtualHosts."jellyfin.roastlan.net" =  {
      forceSSL = true;
      useACMEHost = "roastlan.net";
      locations."/" = {
        proxyPass = "http://localhost:8096";
        proxyWebsockets = true;
        extraConfig =
          # required when the target is also TLS server with multiple hosts
          "proxy_ssl_server_name on;" +
          # required when the server wants to use HTTP Authentication
          "proxy_pass_header Authorization;"
          ;
      };
    };
  };

}
