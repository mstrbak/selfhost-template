# User-edit point.
# Fork this repo, edit values below, commit, then run GitHub Actions workflows.
{
  # Server identity
  hostname = "myserver";
  username = "admin";

  # Domain served by Traefik (DNS-01 via Cloudflare). Wildcard *.<domain> recommended.
  domain    = "example.com";
  acmeEmail = "you@example.com";

  # Tailnet name (e.g. "tail1234.ts.net"). Used by deploy workflow to reach the host.
  tailnet = "tail0000.ts.net";

  # Disk for nixos-anywhere install.
  # Contabo KVM SSD plans: /dev/sda. NVMe plans may need /dev/vda or /dev/nvme0n1.
  diskDevice = "/dev/sda";

  timeZone = "UTC";

  # SSH public key authorized for the user. Used as emergency fallback access.
  sshPublicKey = "ssh-ed25519 AAAA_REPLACE_ME you@laptop";

  # KEEP true until you confirm `tailscale ping <hostname>` works from your laptop.
  # When false: public 22/tcp closes; only Tailscale-side SSH remains.
  publicSshFallback = true;
}
