current_hostname := `hostname -s`
current_username := `whoami`

# List recipes
default:
    @just --list --unsorted

# Build OS configuration
build:
    @just build-host

# Check OS configuration
check:
    @nix flake check --show-trace

# Evaluate configuration without building
eval:
    @just eval-flake
    @just eval-configs

# Evaluate flake syntax and structure
eval-flake:
    @echo "Flake 󱄅 Evaluation: syntax and structure"
    @nix flake show --allow-import-from-derivation

# Switch OS configuration
switch:
    @just switch-host

# Switch on OS Boot Host configuration
boot:
    @just boot-host

# Update flake.lock
update:
    @echo "flake.lock 󱄅 Updating "
    nix flake update

# Build OS configuration
build-host hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname)" = "Linux" ]; then
      echo "NixOS  Building: {{ hostname }}"
      nh os build . --hostname "{{ hostname }}"
    elif [ "$(uname)" = "Darwin" ]; then
      echo "nix-darwin 󰀵 Building: {{ hostname }}"
      nh darwin build . --hostname "{{ hostname }}"
    else
      echo "Unsupported OS: $(uname)"
    fi

# Switch OS configuration
switch-host hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname)" = "Linux" ]; then
      echo "NixOS  Switching: {{ hostname }}"
      nh os switch . --hostname "{{ hostname }}"
    elif [ "$(uname)" = "Darwin" ]; then
      echo "nix-darwin 󰀵 Switching: {{ hostname }}"
      nh darwin switch . --hostname "{{ hostname }}"
    else
      echo "Unsupported OS: $(uname)"
    fi

# Boot OS configuration
boot-host hostname=current_hostname:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "$(uname)" = "Linux" ]; then
      echo "NixOS  Boot: {{ hostname }}"
      nh os boot . --hostname "{{ hostname }}"
    else
      echo "Unsupported OS: $(uname)"
    fi
