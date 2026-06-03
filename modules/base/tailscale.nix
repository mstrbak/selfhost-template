{ pkgs, ... }:
{
  services.tailscale.enable = true;

  # First-boot auto-join. Auth key is placed at /var/lib/tailscale-authkey
  # by nixos-anywhere via extra-files (mode 0400). After successful join the
  # file remains but the oneshot becomes a no-op (guarded by `tailscale status`).
  systemd.services.tailscale-autoconnect = {
    description = "Auto-join Tailscale on first boot";
    after  = [ "network-online.target" "tailscaled.service" ];
    wants  = [ "network-online.target" "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      status=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null || echo '{}')
      if echo "$status" | ${pkgs.jq}/bin/jq -e '.BackendState == "Running"' >/dev/null 2>&1; then
        echo "Tailscale already running; nothing to do."
        exit 0
      fi
      if [ ! -r /var/lib/tailscale-authkey ]; then
        echo "No /var/lib/tailscale-authkey present; skipping autoconnect." >&2
        exit 0
      fi
      authkey=$(cat /var/lib/tailscale-authkey)
      ${pkgs.tailscale}/bin/tailscale up \
        --authkey="$authkey" \
        --ssh \
        --accept-routes
    '';
  };
}
