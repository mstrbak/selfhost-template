# selfhost-template

Public template for spinning up a **NixOS server on a Contabo VPS**, fully managed via GitHub Actions, with **Tailscale-only access** after install.

Fork → edit `config.nix` → set repo secrets → trigger the install workflow. That's the whole flow.

## What you get

- NixOS 24.11 declarative server, installed onto a fresh Contabo VPS by `nixos-anywhere`
- Auto-joins your Tailscale network on first boot
- Firewall on; public 80/443 closed; SSH closes too once you flip a flag
- Traefik reverse proxy bound to the Tailscale interface, valid Let's Encrypt certs via Cloudflare DNS-01
- Two example services: homepage dashboard + Vaultwarden
- Manually trigger the deploy workflow → `nixos-rebuild switch` runs on the server over Tailscale

## Prerequisites

- A Contabo VPS, Ubuntu pre-installed (tested on the **200 GB SSD** KVM plan — disk `/dev/sda`). NVMe plans may expose `/dev/vda` or `/dev/nvme0n1`; you'll edit one line in `config.nix`.
- A Tailscale account
- A domain managed by **Cloudflare** (for DNS-01 ACME)
- A GitHub account

## Setup

### 1. Fork this repo

### 2. Note your VPS root password

Contabo emails you the root password once at provisioning. You'll paste it into a GitHub secret in step 5 — no local SSH commands needed.

After install, password SSH is disabled. Rotate or destroy the original Contabo root password afterwards if you want.

### 3. Tailscale setup

- **Auth key** (admin console → Settings → Keys): create a **reusable**, **pre-approved**, **non-ephemeral** key. Tag it `tag:server`. This key is baked into your server at install time.
- **OAuth client** (admin console → Settings → OAuth clients): create a client with scope `devices:write`, tag `tag:ci`. Used by the deploy workflow to spin up an ephemeral runner node.
- **Tailscale ACL** (admin console → Access Controls): paste the snippet below. It declares the tags and lets the CI runner SSH into your server via Tailscale identity — no SSH keys needed.

  Replace `admin` with the `username` you'll set in `config.nix`:

  ```hujson
  {
    "tagOwners": {
      "tag:server": ["autogroup:admin"],
      "tag:ci":     ["autogroup:admin"]
    },
    "ssh": [
      {
        "action": "accept",
        "src":    ["tag:ci"],
        "dst":    ["tag:server"],
        "users":  ["admin", "root"]
      }
    ],
    "acls": [
      { "action": "accept", "src": ["tag:ci"], "dst": ["tag:server:*"] }
    ]
  }
  ```

### 4. Cloudflare API token

Cloudflare dashboard → My Profile → API Tokens → Create:
- Permission: `Zone:DNS:Edit`
- Zone Resources: include your domain only

### 5. Add GitHub Actions secrets

In your fork → Settings → Secrets and variables → Actions:

| Secret | Purpose |
|---|---|
| `VPS_IP` | Your VPS public IP. Also used to confirm disk wipes. |
| `VPS_ROOT_PASSWORD` | Contabo root password from the welcome email. Used by the install workflow only; after install, password SSH is disabled. |
| `TAILSCALE_AUTHKEY` | The reusable auth key from step 3. |
| `TAILSCALE_OAUTH_CLIENT_ID` | OAuth client ID from step 3. |
| `TAILSCALE_OAUTH_SECRET` | OAuth client secret from step 3. |
| `CLOUDFLARE_DNS_API_TOKEN` | The Cloudflare token from step 4. The deploy workflow pushes it to `/var/lib/traefik/cf-token` on the server. |
| `VAULTWARDEN_ADMIN_TOKEN` | **Argon2-hashed** Vaultwarden admin token. Generate with `docker run --rm -it vaultwarden/server /vaultwarden hash` and paste the resulting `$argon2id$...` string. Leave unset if you don't use Vaultwarden's admin panel. |

The deploy workflow pushes these tokens over Tailscale SSH after each rebuild. Files land at `/var/lib/<svc>/...` with mode 0400 root-owned. Tokens never enter `/nix/store`.

### 6. Edit `config.nix`

```nix
{
  hostname = "myserver";
  username = "admin";
  domain    = "example.com";
  acmeEmail = "you@example.com";
  tailnet   = "tail1234.ts.net";     # your tailnet's DNS suffix
  diskDevice = "/dev/sda";
  timeZone = "Europe/Bratislava";
  sshPublicKey = "ssh-ed25519 AAAA... you@laptop";   # YOUR laptop's pubkey (~/.ssh/id_ed25519.pub) — emergency fallback access
  publicSshFallback = true;          # leave true until lockdown step
}
```

Commit and push.

### 7. Run the install workflow

GitHub → Actions → **Install NixOS** → **Run workflow**. You must type the VPS IP exactly into the confirmation field — this guards against accidental disk wipes.

The workflow takes ~10 minutes. When it finishes the server reboots into NixOS and auto-joins Tailscale.

### 8. Verify Tailscale

From your laptop:

```bash
tailscale status | grep <hostname>
tailscale ping <hostname>
ssh <username>@<hostname>.<tailnet>.ts.net   # works over Tailscale
```

You should also still be able to SSH on the public IP as `<username>` (key-only). That's the fallback.

### 9. Sync `hardware-configuration.nix`

The repo ships with a generic stub at `hosts/server/hardware-configuration.nix`. The real one was generated on your VPS during install — copy it back into the repo so future rebuilds use the accurate kernel modules, filesystems, and hardware quirks for your machine.

From your laptop (over Tailscale):

```bash
scp <username>@<hostname>.<tailnet>.ts.net:/etc/nixos/hardware-configuration.nix \
    hosts/server/hardware-configuration.nix

git add hosts/server/hardware-configuration.nix
git commit -m "sync hardware-configuration.nix from install"
git push
```

Do this **before your first deploy**.

### 10. First deploy

Trigger it manually: GitHub → Actions → **Deploy NixOS** → **Run workflow**. It will:
- Join Tailscale as an ephemeral CI node
- Reach your server over the tailnet
- Run `nixos-rebuild switch`
- Push the Cloudflare and Vaultwarden tokens to `/var/lib/...` and restart the affected services (only if a token actually changed)

Point `*.<your-domain>` DNS A record at your server's Tailscale IP. Cert issuance works because Cloudflare DNS-01 doesn't need the server to be reachable from the internet.

### 11. Lock down

Once you've confirmed `tailscale ping <hostname>` works **and** SSH over Tailscale works:

```nix
# config.nix
publicSshFallback = false;
```

Push, then manually trigger the Deploy NixOS workflow again. It will close public 22/tcp. Your server is now only reachable over Tailscale.

## Recovery

If you lock yourself out (Tailscale broke, key lost, etc.):
- Use the Contabo **VNC console** from their control panel — always works, bypasses everything
- Log in as `<username>` with the password you set, or boot a rescue ISO
- Re-enable `publicSshFallback = true` locally and push, or edit `/etc/nixos/` on the server directly and `nixos-rebuild switch`

## Adding your own service

Use `modules/apps/vaultwarden.nix` as the template. Pattern:

1. Add the service's port to `lib/ports.nix` (sequential from `8003`)
2. Create `modules/apps/<name>.nix` with an OCI container + Traefik labels
3. Import it in `hosts/server/default.nix`
4. Commit and push

## Disk variants

- KVM SSD (default Contabo plan): `/dev/sda`
- NVMe plans (some Contabo S NVMe SKUs): try `/dev/vda` or `/dev/nvme0n1`
- Check by running `lsblk` over SSH on the freshly-provisioned Ubuntu before installing

## Known gaps

This is a young template. See `llm_wiki/todo/` for tracked open items — notably proper secret management (currently CF/Vaultwarden tokens are placed manually after first deploy).

## License

MIT — see `LICENSE`.
