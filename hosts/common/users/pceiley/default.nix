{ pkgs, config, ... }:
let ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in
{
  users.mutableUsers = false;
  users.users.pceiley = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
    ] ++ ifTheyExist [
      "network"
      "docker"
      "podman"
      "git"
      "libvirtd"
    ];
    openssh.authorizedKeys.keys = [ 
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCu6Wma9pEEdK1znwGxUowDZfSolZQjchG2YYuL2aQLO8qxHAqJV5LhBF2wIhnWOBX+9ta4oSdQ7edGh8gbqFH85z/bpnzkBVs6xrFIkuYWDG+eomzpiquWZLrUZWFdYQmkXeZ5oR24IeYHqh4jZJD0xOqnPxy+QivRp9+vcw+OuwWSIQjJGrJGNElbZ5zAXGN55zWx3mNBx9KLpElKuVblldIu/O7ds2R/Gebc7zMGm7QHLKCZ8V7d0B3R/LdfEemDiSrimCb69Fwn0blN5g1NuT4xOUzSIH1Fc9Bi9dXFgGvQrl1MVEeE4FTUzuwP1+sy5D3bT2wVWN2ecvXBrtY8fyzok/R9AsKrL81NqJjkFxtOsmFEDwNnzuJ4D5IKAsuZvx3Zhm3pyi3Oi9DSsGrsLximqWL1rZ5lO7nzUZEAvrUE78GNLTNFN8Cb9P9Oe1Vy9uUN/g/RoW6xZGTYy6kscaQglfivr9HQgGljiWRqikn1PiDr0dgSYcKzHQde1Ts="
    ];
    
  };
}
