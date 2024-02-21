{ config, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.users.cceiley = {
    #passwordFile = "/secrets/passwords/cceiley";
    isNormalUser = true;
    shell = "/run/current-system/sw/bin/nologin";
    extraGroups = [
    ] ++ ifTheyExist [
      "family"
      "multimedia"
      "paperless"
    ];
  };
}
