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

You'll need accounts on four services. All four have free tiers that work for this template (Contabo VPS costs ~€7/month).

| Service | What it does | Sign up |
|---|---|---|
| **GitHub** | Hosts your fork and runs the install/deploy workflows | <https://github.com/signup> |
| **Contabo** | Provides the VPS (Ubuntu pre-installed) | <https://contabo.com/en/vps/> — order any **VPS S/M/L** plan, **200 GB SSD** is what's tested |
| **Tailscale** | Private network ("tailnet") between your laptop, your server, and the CI runner | <https://login.tailscale.com/start> — free tier covers up to 3 users / 100 devices |
| **Cloudflare** | DNS provider for your domain. Used to obtain Let's Encrypt certs (DNS-01 challenge) | <https://dash.cloudflare.com/sign-up>; transfer or add your domain following Cloudflare's onboarding |

Notes on the VPS:
- Tested on Contabo **VPS S 200 GB SSD** (KVM, disk `/dev/sda`)
- Contabo NVMe plans may expose `/dev/vda` or `/dev/nvme0n1` — you'll edit one line in `config.nix`
- During order, select **Ubuntu 24.04 LTS** as the OS template. The exact Ubuntu version doesn't matter — `nixos-anywhere` wipes it anyway.

Notes on the domain:
- You need a domain you control. If you don't have one, register one anywhere (Namecheap, Porkbun, etc.) and point its nameservers at Cloudflare. Cloudflare's free plan is enough.

## Setup

### 1. Fork this repo

### 2. Note your VPS root password and IP

After ordering a VPS, Contabo sends two emails:

1. **"Your VPS is ready"** — contains the **IPv4 address** of your server.
2. **"Your initial root password"** — contains the root password as a plain string.

Open both, copy the IP and the password somewhere temporary (a notes app). You'll paste them into GitHub secrets in step 5.

<!-- screenshot: Contabo welcome email showing root password field -->

After install, password SSH is disabled and root login is disabled. You can rotate or destroy the original Contabo root password from the Contabo Customer Control Panel afterwards (Your Services → your VPS → "Manage" → "Reset root password").

### 3. Tailscale setup

After creating your Tailscale account, you'll do three things in the admin console at <https://login.tailscale.com/admin>: paste an ACL, create a server auth key, and create a CI OAuth client.

#### 3a. Install Tailscale on your laptop

You'll need it to reach your server after install. Download from <https://tailscale.com/download> and log in. Verify with `tailscale status` in a terminal.

While you're there, note your **tailnet name**: open <https://login.tailscale.com/admin/dns> and look at the top of the page — you'll see something like `tail1234.ts.net`. You'll paste this into `config.nix` in step 6.

<!-- screenshot: Tailscale DNS page highlighting the tailnet name -->

#### 3b. Paste the Access Control List (ACL)

Open <https://login.tailscale.com/admin/acls/file>. Replace the entire contents with the snippet below, then click **Save**.

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

This declares two tags (`tag:server` for your VPS, `tag:ci` for GitHub Actions runs) and lets the CI runner SSH into the server via Tailscale identity. No SSH keys involved.

<!-- screenshot: Tailscale ACL editor with snippet pasted -->

#### 3c. Create the server auth key

Open <https://login.tailscale.com/admin/settings/keys>. Click **Generate auth key…**. Configure:

- **Reusable**: ON (allows reinstalls)
- **Ephemeral**: OFF (server stays in the tailnet across reboots)
- **Pre-approved**: ON
- **Tags**: select `tag:server`
- **Expiration**: any (the key is only used during install)

Click **Generate key**. **Copy it now** — it's shown only once. This goes into the `TAILSCALE_AUTHKEY` GitHub secret.

<!-- screenshot: Tailscale auth key creation dialog with the toggles set -->

#### 3d. Create the CI OAuth client

Open <https://login.tailscale.com/admin/settings/oauth>. Click **Generate OAuth client…**. Configure:

- **Description**: e.g. "GitHub Actions deploy"
- **Scopes**: check `Devices > Core > Write` (this is what `devices:write` means in the Tailscale docs)
- **Tags**: select `tag:ci`

Click **Generate client**. You'll see a **Client ID** and a **Client secret**. Copy both — the secret is shown only once. These go into the `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_SECRET` GitHub secrets.

<!-- screenshot: Tailscale OAuth client creation dialog -->

### 4. Cloudflare API token

Used by Traefik on your server to obtain Let's Encrypt certificates via DNS-01 challenge. The token only needs DNS write access on your one domain.

#### 4a. Confirm your domain is on Cloudflare

Open <https://dash.cloudflare.com/>. If you don't see your domain listed:

1. Click **Add a site**, enter your domain.
2. Pick the **Free** plan.
3. Cloudflare shows you two nameservers (e.g. `xxx.ns.cloudflare.com`). Log into your registrar and change your domain's nameservers to those. Propagation takes minutes-to-hours.
4. Wait until Cloudflare's dashboard shows your domain as **Active**.

#### 4b. Create the API token

Open <https://dash.cloudflare.com/profile/api-tokens>. Click **Create Token** → **Get started** next to "Create Custom Token". Configure:

- **Token name**: e.g. "selfhost-template DNS-01"
- **Permissions**: add one row
  - `Zone` / `DNS` / `Edit`
- **Zone Resources**: `Include` / `Specific zone` / select your domain
- **Client IP Address Filtering**: leave blank
- **TTL**: leave blank (no expiration)

Click **Continue to summary** → **Create Token**. Copy the token shown — it's displayed only once. Goes into the `CLOUDFLARE_DNS_API_TOKEN` GitHub secret.

<!-- screenshot: Cloudflare custom token configuration with Zone:DNS:Edit row -->

### 5. Add GitHub Actions secrets

Go to your fork's page on GitHub and navigate:

**Settings** (top tab) → **Secrets and variables** (left sidebar, under Security) → **Actions** → **New repository secret**

Add each row below by clicking **New repository secret**, pasting the exact `Name` and `Secret` value, then **Add secret**.

<!-- screenshot: GitHub repo secrets page with "New repository secret" button highlighted -->

| Name | Value | Where it comes from |
|---|---|---|
| `VPS_IP` | Your VPS's IPv4 address | Contabo "Your VPS is ready" email (step 2) |
| `VPS_ROOT_PASSWORD` | The root password string | Contabo "Your initial root password" email (step 2) |
| `TAILSCALE_AUTHKEY` | `tskey-auth-...` | Auth key generated in step 3c |
| `TAILSCALE_OAUTH_CLIENT_ID` | Looks like `k1234...` | OAuth client ID from step 3d |
| `TAILSCALE_OAUTH_SECRET` | `tskey-client-...` | OAuth client secret from step 3d |
| `CLOUDFLARE_DNS_API_TOKEN` | The token shown after creation | Cloudflare token from step 4b |
| `VAULTWARDEN_ADMIN_TOKEN` | An argon2 hash like `$argon2id$v=19$m=...` | **Optional.** Only set if you want Vaultwarden's `/admin` panel enabled. Generate by running `docker run --rm -it vaultwarden/server /vaultwarden hash` on any machine with Docker — enter a password twice, copy the `$argon2id$...` string it prints. |

The deploy workflow pushes the Cloudflare and Vaultwarden tokens over Tailscale SSH after each rebuild. Files land at `/var/lib/<svc>/...` with mode 0400 root-owned. Tokens never enter `/nix/store`.

### 6. Edit `config.nix`

In your fork, open `config.nix` (root of the repo). Edit each value:

```nix
{
  hostname = "myserver";              # a short name; appears in Tailscale and shell prompt
  username = "admin";                 # MUST match the username in your Tailscale ACL (step 3b)
  domain    = "example.com";          # your Cloudflare-managed domain
  acmeEmail = "you@example.com";      # used by Let's Encrypt for expiry warnings
  tailnet   = "tail1234.ts.net";      # from Tailscale DNS page (step 3a)
  diskDevice = "/dev/sda";            # /dev/sda for Contabo SSD; /dev/vda or /dev/nvme0n1 for some NVMe plans
  timeZone = "Europe/Bratislava";     # IANA tz name; see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
  sshPublicKey = "ssh-ed25519 AAAA... you@laptop";   # YOUR laptop's pubkey — emergency fallback access
  publicSshFallback = true;           # leave true until step 12 (lockdown)
}
```

#### Where do I get `sshPublicKey`?

On your laptop terminal:

```bash
# Mac/Linux — create one if you don't have it:
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -N ''

# Print it:
cat ~/.ssh/id_ed25519.pub
```

Paste the entire single line (starts with `ssh-ed25519 AAAA...` and ends with `your-email@your-machine` or similar) into the `sshPublicKey` field.

Commit and push your changes.

### 7. Run the install workflow

In your fork on GitHub:

1. Click the **Actions** tab.
2. Left sidebar → **Install NixOS (DESTRUCTIVE — wipes the VPS disk)**.
3. Right side → **Run workflow** dropdown.
4. In the **"Type your VPS IP exactly to confirm disk wipe"** field, paste your VPS's IPv4 address (same as the `VPS_IP` secret). This guards against accidental disk wipes.
5. Click **Run workflow** (green button).

<!-- screenshot: GitHub Actions "Install NixOS" workflow_dispatch dialog with IP input field -->

The workflow takes ~10 minutes. Watch the log; the most informative line is the final one from `nixos-anywhere` ("Installation finished successfully").

When it finishes the server reboots into NixOS and auto-joins Tailscale within ~2 minutes.

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

### 10. Point your domain at the Tailscale IP

The services (homepage, Vaultwarden) will be served at `home.<your-domain>` and `vault.<your-domain>`. You need a wildcard DNS record pointing at the server's Tailscale IP.

#### 10a. Find the server's Tailscale IP

From your laptop:

```bash
tailscale ip -4 <hostname>      # e.g. tailscale ip -4 myserver
# prints something like 100.x.y.z
```

Or open <https://login.tailscale.com/admin/machines> and copy the IPv4 from the row for your server.

#### 10b. Add a wildcard A record on Cloudflare

Open <https://dash.cloudflare.com/>, click your domain, then **DNS** → **Records** → **Add record**.

- **Type**: `A`
- **Name**: `*` (literal asterisk — this makes `*.<your-domain>` resolve)
- **IPv4 address**: the `100.x.y.z` from step 10a
- **Proxy status**: **DNS only** (the orange cloud must be OFF — Cloudflare can't proxy Tailscale IPs)
- **TTL**: Auto

Click **Save**.

<!-- screenshot: Cloudflare wildcard A record form with proxy disabled -->

Cert issuance still works because Cloudflare DNS-01 talks to Cloudflare's API, not to your server — the server itself doesn't need to be reachable from the public internet.

### 11. First deploy

In your fork on GitHub:

1. Click the **Actions** tab.
2. Left sidebar → **Deploy NixOS**.
3. Right side → **Run workflow** → **Run workflow**.

<!-- screenshot: GitHub Actions "Deploy NixOS" workflow_dispatch button -->

It will:
- Join Tailscale as an ephemeral CI node
- Reach your server over the tailnet
- Run `nixos-rebuild switch`
- Push the Cloudflare and Vaultwarden tokens to `/var/lib/...` and restart the affected services (only if a token actually changed)

After it completes, open `https://home.<your-domain>` from a Tailscale-connected machine. You should see the homepage dashboard with a valid Let's Encrypt cert.

### 12. Lock down

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
