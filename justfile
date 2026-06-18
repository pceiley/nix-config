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

# Verify Mullvad VPN namespace confinement (netns egress vs host egress)
vpn-check namespace="mullvad":
    #!/usr/bin/env bash
    set -euo pipefail
    ns="{{ namespace }}"
    if ! ip netns list | grep -qw "$ns"; then
      echo "✗ namespace '$ns' not found — is ${ns}.service up?"
      exit 1
    fi
    echo "Mullvad 󰖂 Confinement check (namespace '$ns')"
    host_ip="$(curl -fsS --max-time 10 https://am.i.mullvad.net/ip || echo '?')"
    ns_ip="$(sudo ip netns exec "$ns" curl -fsS --max-time 10 https://am.i.mullvad.net/ip || echo '?')"
    ns_conn="$(sudo ip netns exec "$ns" curl -fsS --max-time 10 https://am.i.mullvad.net/connected || true)"
    echo "  host egress IP : $host_ip"
    echo "  netns egress IP: $ns_ip"
    echo "  netns status   : $ns_conn"
    if echo "$ns_conn" | grep -qi "You are connected to Mullvad" \
       && [ "$ns_ip" != "$host_ip" ] && [ "$ns_ip" != "?" ]; then
      echo "  ✓ confined: '$ns' exits via Mullvad and differs from the host"
    else
      echo "  ✗ NOT confined as expected — do not trust the tunnel until resolved"
      exit 1
    fi

    # Show Mullvad VPN connection stats (wg + exit server)
vpn-stats namespace="mullvad":
    #!/usr/bin/env bash
    set -euo pipefail
    ns="{{ namespace }}"
    sudo ip netns exec "$ns" wg show
    echo
    sudo ip netns exec "$ns" curl -s https://am.i.mullvad.net/connected || true
