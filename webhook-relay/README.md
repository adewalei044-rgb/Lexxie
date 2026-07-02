# Lexxie Webhook Relay

Small always-on server that receives TradingView webhook alerts from the
`Lexxie - Debug Entry Signals` strategy and places the matching order on
Bybit. Runs on a small VPS; managed entirely from your phone.

## What you need first

- A VPS (Vultr, Tokyo region recommended for lowest latency to Bybit).
- An SSH app on your phone (Termius is the standard free option).
- A Bybit API key with **Trade permission only** (no withdrawal), created
  under Bybit's API Management and IP-whitelisted to your VPS's IP.

## Setup (from your phone, via Termius)

1. SSH into your fresh Ubuntu 22.04 VPS as `root`.
2. Run the installer, pointing it at this repo's branch:

   ```
   curl -fsSL https://raw.githubusercontent.com/adewalei044-rgb/lexxie/claude/tradingview-debug-entry-signals-uy949p/webhook-relay/install.sh | bash -s -- claude/tradingview-debug-entry-signals-uy949p
   ```

   This installs Node.js, Nginx, creates a locked-down service user, pulls
   this code, installs dependencies, sets up a systemd service, and enables
   a firewall (SSH/HTTP/HTTPS only). It prints the exact next steps at the
   end - follow them:

3. Edit `/opt/lexxie-relay/.env` (`nano /opt/lexxie-relay/.env`) and fill in:
   - `WEBHOOK_SECRET` - generate with `openssl rand -hex 24`.
   - `BYBIT_API_KEY` / `BYBIT_API_SECRET`.
   - Leave `BYBIT_TESTNET=true` until you've confirmed everything works.
   - Choose position sizing: either `RISK_USDT` (risk a fixed $ amount per
     trade, sized off the entry/stop distance Lexxie sends) or `FIXED_QTY`
     (always trade the same size). Set `QTY_STEP` to match your symbol's
     minimum order increment on Bybit.
4. `systemctl start lexxie-relay` then `systemctl status lexxie-relay` to
   confirm it's running, and `journalctl -u lexxie-relay -f` to watch logs.
5. (Recommended) Put it behind HTTPS with Nginx + Let's Encrypt - the
   installer prints the exact commands.
6. In TradingView, create an alert on the Lexxie script with **Condition:
   Order fills** (covers entries and exits) and set the **Webhook URL**
   under Notifications to:

   ```
   https://YOUR_DOMAIN/hook/<your WEBHOOK_SECRET>
   ```

7. Test on `BYBIT_TESTNET=true` with tiny size first. Only flip to live
   trading (`BYBIT_TESTNET=false`, real API keys with real funds) once
   you've watched several test trades land correctly.

## How it works

- TradingView POSTs the JSON `alert_message` your Lexxie strategy already
  builds on every entry/exit (`buy` / `sell` / `close_long` / `close_short`)
  to `/hook/<secret>`.
- The relay checks the secret in the URL path, parses the JSON, and calls
  Bybit's v5 API: a `Market` order to open, and a `reduceOnly` `Market`
  order sized to the current open position to close.
- No Pine Script changes are needed - the secret lives only in the
  TradingView alert's Webhook URL field, not in the script itself.

## Files

- `server.js` - the relay's HTTP server and webhook handler.
- `bybit.js` - Bybit v5 request signing and order/position calls.
- `install.sh` - one-shot VPS setup script (see above).
- `lexxie-relay.service` - systemd unit so the relay survives reboots/crashes.
- `nginx.conf.template` - reverse proxy config for HTTPS via Nginx.
- `.env.example` - all configuration options, copy to `.env` and fill in.

## Security notes

- Never commit `.env` - it holds your live API secret.
- Use a Bybit API key scoped to **Trade only**, never withdrawal.
- IP-whitelist the Bybit key to your VPS's IP.
- Keep the webhook secret long and random; anyone with the URL can trigger
  trades on your account.
