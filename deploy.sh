#!/usr/bin/env bash

build_remote=false

hosts="$1"
shift

if [ -z "$hosts" ]; then
    echo "No hosts to deploy"
    exit 2
fi

for host in ${hosts//,/ }; do
    sudo nixos-rebuild --flake .\#$host switch
done
