# Jewel Jam

A mobile-friendly **match-3 puzzle game** that runs entirely in the browser, plus everything you need to host it yourself on any Linux machine or for free on the web.

**Play it now:** https://kitmop.github.io/jewel-jam/

## The game

Jewel Jam is a 10-level match-3 game in the spirit of classic "swap and match" puzzlers, built for phones (iOS Safari in particular) but playable on any modern browser.

- **Play:** swipe a gem toward a neighbour, or tap two adjacent gems, to swap them. Line up 3 or more of the same shape to clear them. Gems above fall down and new ones drop in, so chain reactions (combos) score more.
- **Special gems:**
  - Match **4** in a row to make a line gem that clears a whole row or column.
  - Match in an **L or T** shape to make a bomb that clears a 3×3 area.
  - Match **5** in a row to make a colour bomb. Swap it with a gem to clear every gem of that colour.
  - Special gems can set each other off for chain reactions.
- **Goals:** each level has a score target and, depending on the level, a number of gems to collect and/or **jelly** tiles to clear (some tiles take two hits). You have a limited number of moves.
- **Stars:** 1 to 3 stars per level, plus a bonus for leftover moves. Levels unlock in order, and progress is saved in your browser.
- **Helpers:** a hint button, and an automatic reshuffle if no moves are left.
- **Phone-friendly:** full-screen "Add to Home Screen" support, no scrolling or zooming, safe-area aware layout, portrait and landscape.

The repo also contains an older bonus game, **Gem Rush** (`public/gemrush.html`), a small 3D arena game made with Three.js.

## Codebase

```
.
├── public/                  # the whole website (static files, no build step)
│   ├── index.html           # Jewel Jam: HTML, CSS and JS in one file
│   ├── gemrush.html         # Gem Rush (Three.js loaded from a CDN)
│   └── apple-touch-icon.png # home-screen icon for iOS
├── server.js                # tiny Express server that serves public/ (optional)
├── ecosystem.config.js      # PM2 process definition for running server.js
├── setup.sh                 # one-shot self-hosting setup for apt-based Linux
├── netlify.toml             # config for hosting on Netlify
├── .github/workflows/pages.yml  # deploys public/ to GitHub Pages on every push
└── package.json
```

How the game is built (`public/index.html`):

- **No framework, no bundler, no dependencies.** Vanilla JavaScript and a 2D canvas for the board. Open the file in a browser and it works.
- **Rendering:** gem sprites are drawn once per cell size onto offscreen canvases, then blitted every frame. Animations use a small promise-based tween system.
- **Game logic:** the board is a grid of piece objects. Matching, special-gem creation, chain reactions, gravity, refill and reshuffle live in `findMatches`, `expand`, `clearSet`, `gravity` and `resolve`. Levels are plain data in the `LEVELS` array at the top of the script, so adding or tweaking a level means editing one object.
- **Input:** pointer events (swipe and tap-tap) on the canvas. iOS gestures such as pull-to-refresh, pinch zoom, double-tap zoom and text selection are disabled.
- **Saving:** progress and the sound setting go to `localStorage` (the game still works if storage is blocked).
- **Test hooks:** open the page with `?debug` to expose `window.__game` (used for automated play-testing), and `?debug&fast` to skip animations.

## Run it locally

You need Node.js 20 or newer.

```bash
git clone https://github.com/kitmop/jewel-jam.git
cd jewel-jam
npm install
npm start                # http://localhost:3000
```

Jewel Jam has no server-side logic, so any static file server works too, for example `python3 -m http.server 8000 --directory public`. Opening `public/index.html` directly in a browser also works.

## Put it online

Because the game is just static files, the easiest options need no server of your own and are free. Pick one.

### Option 1: GitHub Pages (what the live link uses)

The included workflow publishes `public/` automatically.

1. Fork this repo, or push it to a new **public** GitHub repo.
2. In the repo, open **Settings → Pages** and set **Source** to **GitHub Actions**.
3. Push to `main` (or run the workflow from the **Actions** tab). When it finishes, your site is at `https://<your-username>.github.io/<repo-name>/`.

### Option 2: Cloudflare Pages (free, URL ends in `.pages.dev`)

1. Sign in at the Cloudflare dashboard and go to **Workers & Pages → Create application → Pages → Connect to Git**.
2. Pick your GitHub repo and click **Begin setup**.
3. Set **Production branch** to `main`, leave **Build command** empty, and set **Build output directory** to `public`.
4. Click **Save and Deploy**. Your site will be at `https://<project-name>.pages.dev`, and every push redeploys it.

### Option 3: Netlify (free, URL ends in `.netlify.app`)

1. Sign in at netlify.com and choose **Add new site → Import an existing project**, then pick your GitHub repo.
2. `netlify.toml` already sets the publish directory to `public`. Leave the build command empty.
3. Deploy. You get `https://<site-name>.netlify.app`, and you can rename the site under **Site configuration**.

> Options 2 and 3 follow the providers' documentation but have not been test-deployed from this repo. Option 1 is the one that has been deployed and checked.

### Option 4: Host it on your own Linux machine

See the next section.

## Self-hosting on a Linux machine

Useful if you want full control, or want to keep the game on your own network. Any always-on Linux box works: a spare laptop, a mini PC, a Raspberry Pi, a home server or a VPS.

**What you need**

- A systemd-based distro. `setup.sh` targets **apt-based** ones (Debian, Ubuntu, Linux Mint, Raspberry Pi OS, and so on). On Fedora, Arch and others, follow the manual steps below with your own package manager.
- Node.js 20 or newer, and `sudo` access.

### The quick way (apt-based distros)

```bash
git clone https://github.com/kitmop/jewel-jam.git
cd jewel-jam
DRY_RUN=1 ./setup.sh      # optional: print every command without running anything
./setup.sh                # run as your normal user; it asks for sudo when needed
```

The script installs Node.js (if missing), PM2 and the app dependencies, starts the server, enables start on boot, and installs `cloudflared`. For public access, add one of:

```bash
CF_TUNNEL_TOKEN=<token> ./setup.sh   # permanent tunnel on your own domain (see below)
QUICK_TUNNEL=1 ./setup.sh            # random temporary URL, no account needed
```

### The manual way

**1. Install Node.js and PM2**

Use your distro's packages, [NodeSource](https://github.com/nodesource/distributions), or nvm. On Debian/Ubuntu:

```bash
sudo apt-get update && sudo apt-get install -y curl ca-certificates gnupg
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pm2
```

**2. Install and test**

```bash
cd jewel-jam
npm install --omit=dev
node server.js                      # Ctrl+C to stop
curl http://localhost:3000/healthz  # prints: ok
```

The server listens on `0.0.0.0:3000` by default. Change it with the `PORT` and `HOST` environment variables.

**3. Keep it running and start on boot**

```bash
pm2 start ecosystem.config.js
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp $HOME
pm2 save
```

Handy commands: `pm2 status`, `pm2 logs gameserver`, `pm2 restart gameserver`, `pm2 stop gameserver`.

**4. Make it reachable from the internet**

*Cloudflare Tunnel (recommended).* It needs no router port forwarding and works behind CGNAT. HTTPS is handled for you. Install `cloudflared` from [Cloudflare's install page](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/), then pick one:

- **Permanent URL** (needs a free Cloudflare account and a domain on Cloudflare DNS): in the dashboard go to **Zero Trust → Networks → Tunnels → Create a tunnel**, copy the token, and add a public hostname such as `game.example.com` pointing to `http://localhost:3000`. Then run:
  ```bash
  sudo cloudflared service install <TOKEN>
  ```
  This installs a systemd service that starts on boot (`systemctl status cloudflared`).
- **Temporary URL** (no account, changes on every restart):
  ```bash
  pm2 start "$(command -v cloudflared)" --name quick-tunnel --interpreter none -- tunnel --no-autoupdate --url http://localhost:3000
  pm2 save
  pm2 logs quick-tunnel --lines 30 --nostream | grep trycloudflare.com
  ```

*Other ways:* forward a port on your router and put a reverse proxy such as Caddy or nginx in front for HTTPS, use a VPN or mesh network such as Tailscale to reach it privately, or run it on a VPS with a public IP.

**5. Optional: stop a laptop sleeping when the lid is closed**

Skip this on desktops and servers.

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

Desktop environments (GNOME, Cinnamon, KDE, ...) have their own power settings too. Set "when the lid is closed" and "suspend when inactive" to *do nothing* in your system's Power settings. On Cinnamon, `setup.sh` also does this through `gsettings`.

**Undo it:**

```bash
sudo rm /etc/systemd/logind.conf.d/99-homeserver.conf
sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo systemctl kill -s HUP systemd-logind
# Cinnamon only: restore its default power settings
P=org.cinnamon.settings-daemon.plugins.power
for k in lid-close-ac-action lid-close-battery-action sleep-inactive-ac-type sleep-inactive-battery-type sleep-inactive-ac-timeout sleep-inactive-battery-timeout; do gsettings reset $P $k; done
```

**Stop or remove the server**

```bash
pm2 delete gameserver && pm2 save      # remove the app (and quick-tunnel the same way if used)
sudo systemctl disable --now cloudflared   # only if you installed the tunnel service
```

### Security notes

- The server only serves static files from `public/`. It has no database, accounts or user input.
- It binds to `0.0.0.0`, so it is reachable on your local network. For tunnel-only access set `HOST: '127.0.0.1'` in `ecosystem.config.js` and run `pm2 restart gameserver --update-env`.
- Don't expose SSH (port 22) to the internet.
- An old worn battery in a laptop that stays plugged in is a fire risk, so consider removing it.

## Playing on an iPhone

1. Open the URL in **Safari**.
2. Tap **Share → Add to Home Screen** for a full-screen, app-like experience.

## Notes

- Gem Rush loads Three.js from jsDelivr, pinned to `three@0.149.0`, and shows an error message if the CDN can't be reached. Jewel Jam has no external dependencies.
- HTML is served with `no-cache`, so edits to `public/` show up on reload without restarting the server.
