{ pkgs, config, lib, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.mutableUsers = false;

  users.users.pceiley = {
    hashedPasswordFile = "/persist/secrets/passwords/pceiley";
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
}
