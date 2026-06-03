# Non-sensitive defaults. Edit and commit these.
#
# Sensitive fields (hostname, username, domain, acmeEmail, tailnet, sshPublicKey)
# are injected from GitHub Actions secrets at workflow run time via a generated
# `config.local.nix` (gitignored). See README §5.
{
  # Disk for nixos-anywhere install.
  # Contabo KVM SSD plans: /dev/sda. NVMe plans may need /dev/vda or /dev/nvme0n1.
  diskDevice = "/dev/sda";

  timeZone = "UTC";

  # KEEP true until you confirm `tailscale ping <hostname>` works from your laptop.
  # When false: public 22/tcp closes; only Tailscale-side SSH remains.
  publicSshFallback = true;
}
