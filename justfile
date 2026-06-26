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

# Edit a sops file using THIS host's key (no user key needed on the box)
sops-edit file="secrets/secrets.yaml":
    #!/usr/bin/env bash
    set -euo pipefail
    key="$(mktemp /dev/shm/hostage.XXXXXX)"
    trap 'rm -f "$key"' EXIT
    sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > "$key"
    SOPS_AGE_KEY_FILE="$key" TMPDIR=/dev/shm sops "{{ file }}" || test $? -eq 200

# Re-encrypt secrets to current .sops.yaml recipients using THIS host's key
# (no personal key needed). Only works if this host is STILL a recipient of the
# file as currently encrypted — i.e. use it when adding/removing OTHER hosts'
# keys, NOT when rotating this host's own key.
sops-updatekeys-host file="secrets/secrets.yaml":
    #!/usr/bin/env bash
    set -euo pipefail
    key="$(mktemp /dev/shm/hostage.XXXXXX)"
    trap 'rm -f "$key"' EXIT
    sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key > "$key"
    SOPS_AGE_KEY_FILE="$key" TMPDIR=/dev/shm sops updatekeys "{{ file }}"

# Re-encrypt secrets to current .sops.yaml recipients, using your PERSONAL age
# key (paste when prompted). Needed after rotating host keys, since the host's
# own key can no longer decrypt the not-yet-rewrapped file.
sops-updatekeys-personal file="secrets/secrets.yaml":
    #!/usr/bin/env bash
    set -euo pipefail
    key="$(mktemp /dev/shm/userage.XXXXXX)"
    trap 'rm -f "$key"' EXIT
    printf 'Paste personal age key (AGE-SECRET-KEY-1...), then Enter: ' >&2
    read -rs secret; echo >&2
    printf '%s' "$secret" > "$key"
    unset secret
    SOPS_AGE_KEY_FILE="$key" TMPDIR=/dev/shm sops updatekeys "{{ file }}"

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
