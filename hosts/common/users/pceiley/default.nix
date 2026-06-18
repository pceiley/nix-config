{ pkgs, config, lib, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.mutableUsers = false;

  users.users.pceiley = {
    hashedPasswordFile = config.sops.secrets.pceiley_password.path;
    #initialPassword = "Chang3m3";
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
    ] ++ ifTheyExist [
      "family"
      "multimedia"
      "network"
      "docker"
      "paperless"
      "podman"
      "git"
      "libvirtd"
    ];
    openssh.authorizedKeys.keys = [ 
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOOoqTRszeMHn62uhVCRQGYvmBPcnJzA1T4zG0bRpcmK"
    ];
  };

  # Login password hash. neededForUsers makes sops decrypt this early
  # (into /run/secrets-for-users) BEFORE users are created. Do not set
  # owner/group/mode on a neededForUsers secret.
  sops.secrets.pceiley_password = {
    neededForUsers = true;
  };
}
