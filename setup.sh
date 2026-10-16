#!/usr/bin/env bash
# Turns an apt-based Linux machine (Debian, Ubuntu, Linux Mint, ...) into an always-on web server.
#
#   ./setup.sh                      # everything except the Cloudflare tunnel
#   CF_TUNNEL_TOKEN=eyJ... ./setup.sh   # ...and install a permanent named tunnel
#   QUICK_TUNNEL=1 ./setup.sh           # ...or a random *.trycloudflare.com tunnel (no account)
#   DRY_RUN=1 ./setup.sh                # print what would run, change nothing
#
# Run as your normal user (NOT with sudo); it calls sudo only where needed.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN="${DRY_RUN:-0}"
CF_TUNNEL_TOKEN="${CF_TUNNEL_TOKEN:-}"
QUICK_TUNNEL="${QUICK_TUNNEL:-0}"

say()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# run CMD...  -> executes (or just prints in DRY_RUN mode)
run() {
  if [ "$DRY_RUN" = "1" ]; then printf '[dry-run] %s\n' "$*"; else "$@"; fi
}
# write_root_file PATH  (content on stdin)
write_root_file() {
  local path="$1" content
  content="$(cat)"
  if [ "$DRY_RUN" = "1" ]; then
    printf '[dry-run] write %s:\n%s\n' "$path" "$content"
  else
    printf '%s\n' "$content" | sudo tee "$path" >/dev/null
  fi
}
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not root (pm2 must belong to your user)."
[ "$DRY_RUN" = "1" ] || have sudo || die "sudo is required."
[ -f "$PROJECT_DIR/server.js" ] || die "server.js not found next to setup.sh."
have apt-get || die "This script expects an apt-based system (Linux Mint/Ubuntu/Debian)."

# ----------------------------------------------------------------------------
say "1/6  Keep the laptop awake with the lid closed"
# ----------------------------------------------------------------------------
run sudo mkdir -p /etc/systemd/logind.conf.d
write_root_file /etc/systemd/logind.conf.d/99-homeserver.conf <<'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
CONF
# SIGHUP makes logind re-read its config without killing your session.
run sudo systemctl kill -s HUP systemd-logind
# Make suspend/hibernate impossible (undo: sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target)
run sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# Cinnamon (Linux Mint) has its own lid/idle power handling on top of logind.
set_gsetting() {   # schema key value  (skips silently if the schema/key does not exist)
  local schema="$1" key="$2" value="$3" keys
  keys="$(gsettings list-keys "$schema" 2>/dev/null || true)"
  if printf '%s\n' "$keys" | grep -qx "$key"; then
    run gsettings set "$schema" "$key" "$value"
  fi
}
if have gsettings && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  P=org.cinnamon.settings-daemon.plugins.power
  set_gsetting "$P" lid-close-ac-action "'nothing'"
  set_gsetting "$P" lid-close-battery-action "'nothing'"
  set_gsetting "$P" sleep-inactive-ac-type "'nothing'"
  set_gsetting "$P" sleep-inactive-battery-type "'nothing'"
  set_gsetting "$P" sleep-inactive-ac-timeout 0
  set_gsetting "$P" sleep-inactive-battery-timeout 0
else
  warn "No desktop session detected; skipped Cinnamon power settings (logind settings above still apply)."
fi

# ----------------------------------------------------------------------------
say "2/6  Install Node.js LTS"
# ----------------------------------------------------------------------------
node_major=0
if have node; then node_major="$(node -p 'process.versions.node.split(".")[0]')"; fi
if [ "$node_major" -ge 20 ]; then
  echo "Node $(node -v) already installed, skipping."
else
  run sudo apt-get update
  run sudo apt-get install -y curl ca-certificates gnupg
  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
  else
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  fi
  run sudo apt-get install -y nodejs
fi

# ----------------------------------------------------------------------------
say "3/6  Install PM2 and the app dependencies"
# ----------------------------------------------------------------------------
if have pm2; then echo "pm2 already installed, skipping."; else run sudo npm install -g pm2; fi
( cd "$PROJECT_DIR" && run npm install --omit=dev --no-audit --no-fund )

# ----------------------------------------------------------------------------
say "4/6  Start the server with PM2 and enable start on boot"
# ----------------------------------------------------------------------------
( cd "$PROJECT_DIR" && run pm2 startOrRestart ecosystem.config.js --update-env )
run sudo env "PATH=$PATH:/usr/bin" pm2 startup systemd -u "$USER" --hp "$HOME"
run pm2 save

# ----------------------------------------------------------------------------
say "5/6  Install cloudflared"
# ----------------------------------------------------------------------------
if have cloudflared; then
  echo "cloudflared already installed, skipping."
else
  run sudo mkdir -p --mode=0755 /usr/share/keyrings
  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg"
  else
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  fi
  write_root_file /etc/apt/sources.list.d/cloudflared.list <<'LIST'
deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main
LIST
  run sudo apt-get update
  run sudo apt-get install -y cloudflared
fi

# ----------------------------------------------------------------------------
say "6/6  Cloudflare Tunnel"
# ----------------------------------------------------------------------------
if [ -n "$CF_TUNNEL_TOKEN" ]; then
  units="$(systemctl list-unit-files cloudflared.service 2>/dev/null || true)"
  if printf '%s\n' "$units" | grep -q '^cloudflared.service'; then
    echo "cloudflared systemd service already installed, skipping."
  else
    run sudo cloudflared service install "$CF_TUNNEL_TOKEN"
  fi
elif [ "$QUICK_TUNNEL" = "1" ]; then
  if pm2 describe quick-tunnel >/dev/null 2>&1; then
    echo "PM2 process 'quick-tunnel' already exists, skipping."
  else
    CF_BIN="$(command -v cloudflared || echo /usr/bin/cloudflared)"
    run pm2 start "$CF_BIN" --name quick-tunnel --interpreter none -- tunnel --no-autoupdate --url http://localhost:3000
    run pm2 save
    if [ "$DRY_RUN" != "1" ]; then
      echo "Waiting for the public URL..."
      url=""
      for _ in $(seq 1 30); do
        url="$(grep -ho 'https://[a-z0-9-]*\.trycloudflare\.com' "$HOME"/.pm2/logs/quick-tunnel-*.log 2>/dev/null | tail -n1 || true)"
        [ -n "$url" ] && break
        sleep 1
      done
      if [ -n "$url" ]; then echo "Your game is live at: $url   (changes whenever the tunnel restarts)"; else warn "URL not found yet; run: pm2 logs quick-tunnel"; fi
    fi
  fi
else
  echo "No tunnel configured. Re-run with CF_TUNNEL_TOKEN=... or QUICK_TUNNEL=1 (see README.md)."
fi

say "Done"
if [ "$DRY_RUN" != "1" ]; then
  sleep 1
  echo "Local check: $(curl -fsS http://localhost:3000/healthz || echo FAILED)"
  pm2 status
fi
