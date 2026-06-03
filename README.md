# selfhost-template

Public template for spinning up a **NixOS server on a Contabo VPS**, fully managed via GitHub Actions, with **Tailscale-only access** after install.

Fork → edit `config.nix` → set repo secrets → trigger the install workflow. That's the whole flow.

## What you get

- NixOS 24.11 declarative server, installed onto a fresh Contabo VPS by `nixos-anywhere`
- Auto-joins your Tailscale network on first boot
- Firewall on; public 80/443 closed; SSH closes too once you flip a flag
- Traefik reverse proxy bound to the Tailscale interface, valid Let's Encrypt certs via Cloudflare DNS-01
- Two example services: homepage dashboard + Vaultwarden
- Push to `main` → `nixos-rebuild switch` runs on the server over Tailscale

## Prerequisites

- A Contabo VPS, Ubuntu pre-installed (tested on the **200 GB SSD** KVM plan — disk `/dev/sda`). NVMe plans may expose `/dev/vda` or `/dev/nvme0n1`; you'll edit one line in `config.nix`.
- A Tailscale account
- A domain managed by **Cloudflare** (for DNS-01 ACME)
- A GitHub account

## Setup

### 1. Fork this repo

### 2. Get root SSH access on the VPS

From your laptop (Contabo emails you the root password once):

```bash
ssh-copy-id root@<VPS_IP>
ssh root@<VPS_IP> 'echo ok'   # verify
```

### 3. Generate a deploy SSH keypair

This key lets GitHub Actions SSH into your server over Tailscale after install.

```bash
ssh-keygen -t ed25519 -f ./deploy_key -N ''
cat deploy_key.pub      # → goes into config.nix
cat deploy_key          # → goes into the DEPLOY_SSH_KEY secret
```

### 4. Tailscale setup

- **Auth key** (admin console → Settings → Keys): create a **reusable**, **pre-approved**, **non-ephemeral** key. Tag it `tag:server`. This key is baked into your server at install time.
- **OAuth client** (admin console → Settings → OAuth clients): create a client with scope `devices:write`, tag `tag:ci`. Used by the deploy workflow to spin up an ephemeral runner node.
- Make sure `tag:server` and `tag:ci` exist in your ACL.

### 5. Cloudflare API token

Cloudflare dashboard → My Profile → API Tokens → Create:
- Permission: `Zone:DNS:Edit`
- Zone Resources: include your domain only

### 6. Add GitHub Actions secrets

In your fork → Settings → Secrets and variables → Actions:

| Secret | Purpose |
|---|---|
| `VPS_IP` | Your VPS public IP. Also used to confirm disk wipes. |
| `VPS_ROOT_SSH_KEY` | Private key (matching the one you `ssh-copy-id`'d) for `root@VPS_IP`. Used during install only. |
| `TAILSCALE_AUTHKEY` | The reusable auth key from step 4. |
| `TAILSCALE_OAUTH_CLIENT_ID` | OAuth client ID from step 4. |
| `TAILSCALE_OAUTH_SECRET` | OAuth client secret from step 4. |
| `DEPLOY_SSH_KEY` | Private key (`deploy_key` from step 3). |

The Cloudflare token is handled after the first deploy — see step 10.

### 7. Edit `config.nix`

```nix
{
  hostname = "myserver";
  username = "admin";
  domain    = "example.com";
  acmeEmail = "you@example.com";
  tailnet   = "tail1234.ts.net";     # your tailnet's DNS suffix
  diskDevice = "/dev/sda";
  timeZone = "Europe/Bratislava";
  sshPublicKey = "ssh-ed25519 AAAA... deploy_key";   # pubkey from step 3
  publicSshFallback = true;          # leave true until lockdown step
}
```

Commit and push.

### 8. Run the install workflow

GitHub → Actions → **Install NixOS** → **Run workflow**. You must type the VPS IP exactly into the confirmation field — this guards against accidental disk wipes.

The workflow takes ~10 minutes. When it finishes, the server reboots, comes up in NixOS, and auto-joins Tailscale.

### 9. Verify Tailscale

From your laptop:

```bash
tailscale status | grep <hostname>
tailscale ping <hostname>
ssh <username>@<hostname>.<tailnet>.ts.net   # works over Tailscale
```

You should also still be able to SSH on the public IP as `<username>` (key-only). That's the fallback.

### 10. First deploy & Cloudflare token

Push any commit to `main` (or trigger the deploy workflow manually). It will:
- Join Tailscale as an ephemeral CI node
- Reach your server over the tailnet
- Run `nixos-rebuild switch`

Then place the Cloudflare token on the server (one-time, manual, until proper secret management is wired in — see `llm_wiki/todo/08-secrets-management.md`):

```bash
ssh <username>@<hostname>.<tailnet>.ts.net
sudo bash -c 'echo "CF_DNS_API_TOKEN=YOUR_TOKEN_HERE" > /var/lib/traefik/cf-token'
sudo chmod 400 /var/lib/traefik/cf-token
sudo systemctl restart docker-traefik
```

Point `*.<your-domain>` DNS A record at your server's Tailscale IP. Cert issuance works because Cloudflare DNS-01 doesn't need the server to be reachable from the internet.

### 11. Lock down

Once you've confirmed `tailscale ping <hostname>` works **and** SSH over Tailscale works:

```nix
# config.nix
publicSshFallback = false;
```

Push. The next deploy closes public 22/tcp. Your server is now only reachable over Tailscale.

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
