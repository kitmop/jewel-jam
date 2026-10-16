# Jewel Jam + home game server

**Jewel Jam** is a 10-level match-3 game (`public/index.html`, single file, no build step).
The 3D rolling-ball game from earlier lives at `public/gemrush.html`.

## Free permanent hosting: GitHub Pages

Every push to `main` deploys `public/` via `.github/workflows/pages.yml`.
The site is at `https://<your-user>.github.io/<repo>/` (HTTPS, free, works when your laptop is off).

## Self-hosting on a Linux Mint laptop (optional)

```
homeserver/
├── .github/workflows/     # GitHub Pages deploy
├── setup.sh               # one-shot setup (lid, Node, PM2, boot, cloudflared)
├── server.js              # Express static server on 0.0.0.0:3000
├── ecosystem.config.js    # PM2 app definition
├── package.json
└── public/
    ├── index.html         # Jewel Jam (match-3, single file)
    ├── gemrush.html       # Gem Rush (3D, Three.js)
    └── apple-touch-icon.png
```

## Quick start

```bash
cd ~/homeserver
DRY_RUN=1 ./setup.sh      # optional: preview every command, changes nothing
./setup.sh                # run as your normal user; it asks for sudo when needed
```

Then follow **Step 5** below to publish it with a Cloudflare Tunnel.

---

## Manual steps (what `setup.sh` does)

### 1. Don't sleep when the lid is closed

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/99-homeserver.conf >/dev/null <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
CONF
sudo systemctl kill -s HUP systemd-logind      # reload config, keeps your session
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

Linux Mint's Cinnamon desktop has its own power daemon, so also run (in the laptop's desktop session):

```bash
P=org.cinnamon.settings-daemon.plugins.power
gsettings set $P lid-close-ac-action 'nothing'
gsettings set $P lid-close-battery-action 'nothing'
gsettings set $P sleep-inactive-ac-type 'nothing'
gsettings set $P sleep-inactive-battery-type 'nothing'
```

Undo: `sudo rm /etc/systemd/logind.conf.d/99-homeserver.conf && sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target`

### 2. Node.js LTS + PM2

```bash
sudo apt-get update && sudo apt-get install -y curl ca-certificates gnupg
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2
```

### 3. Install and test the server

```bash
cd ~/homeserver
npm install --omit=dev
node server.js            # Ctrl+C to stop
curl http://localhost:3000/healthz     # -> ok
```

### 4. Run it under PM2, start on boot

```bash
cd ~/homeserver
pm2 start ecosystem.config.js
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp $HOME
pm2 save
```

Useful: `pm2 status`, `pm2 logs gameserver`, `pm2 restart gameserver`.

### 5. Public HTTPS with Cloudflare Tunnel (no port forwarding, works behind CGNAT)

Install `cloudflared`:

```bash
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install -y cloudflared
```

**Option A, permanent URL on your own domain (recommended; free Cloudflare account, domain on Cloudflare DNS)**

1. Cloudflare dashboard → **Zero Trust → Networks → Tunnels → Create a tunnel → Cloudflared**.
2. Name it, copy the **token** from the install command it shows (the long `eyJ...` string).
3. Add a **Public hostname**: e.g. `game.yourdomain.com` → Service type `HTTP`, URL `localhost:3000`.
4. On the laptop:

   ```bash
   sudo cloudflared service install <PASTE_TOKEN>
   ```

   This installs a **systemd service** that runs in the background and starts on boot. Check it with `systemctl status cloudflared`.
   Or let the script do it: `CF_TUNNEL_TOKEN=<token> ./setup.sh`

**Option B, instant test URL, no account (URL changes on every restart)**

```bash
pm2 start "$(command -v cloudflared)" --name quick-tunnel --interpreter none -- tunnel --no-autoupdate --url http://localhost:3000
pm2 save
pm2 logs quick-tunnel --lines 30 --nostream | grep trycloudflare.com
```

(or `QUICK_TUNNEL=1 ./setup.sh`)

### 6. Play on iPhone

1. Open the HTTPS URL in **Safari**.
2. Share button → **Add to Home Screen** → full-screen, no browser bars.
3. Drag anywhere on the left half of the screen to roll; collect gems before time runs out.

---

## Notes

- **Three.js** is loaded from jsDelivr, pinned to `three@0.149.0` (classic script build, works on older iOS versions too). If the CDN is unreachable the page shows an error message.
- `server.js` listens on `0.0.0.0` so it's also reachable on your LAN (`http://<laptop-ip>:3000`). If you want tunnel-only access, set `HOST: '127.0.0.1'` in `ecosystem.config.js` and `pm2 restart gameserver --update-env`.
- Laptop battery: an old swollen/worn battery is a fire risk when always plugged in. Consider removing it if the laptop runs on AC alone.
- Update the game: edit `public/index.html`; no restart needed (HTML is served with `no-cache`).
- Add `?debug` to the URL to expose `window.__game` for testing.
